import React, { useEffect, useRef, useState } from 'react';
import { flushSync } from 'react-dom';
import { useSelector } from 'react-redux';
import { Box, IconButton } from '@mui/material';
import FiberManualRecordIcon from '@mui/icons-material/FiberManualRecord';
import NavigateBeforeIcon from '@mui/icons-material/NavigateBefore';
import NavigateNextIcon from '@mui/icons-material/NavigateNext';
import { RootState } from '@/store/store';
import { trackEvent, ProductParams } from '@/plugins/firebase/analytics';
import { waitForTurn } from './drawQueue';

// ナビボタンはスライド下のインジケータ行に重ねて置き、幅の狭い画面でもチャートの下端に重ならないようにする
const navRowHeight = 40;
const autoPlayInterval = 6000;
// 指を離した後の慣性・吸着のスクロールが終わってから、表示したスライドを確定する
const scrollSettleDelay = 150;
// 端で外側へこれ以上動かしたら、反対の端へ移す
const edgeSwipeDistance = 50;
const chartTypes: ProductParams['chart_type'][] = [
  'bs',
  'pl',
  'cf',
  'fcf',
  'indicators',
];

// カルーセルの操作感（6秒の自動切替・ナビボタン・インジケータ・スワイプ）を全カードで統一するラッパー。
// 自動切替のON/OFFだけ画面共通の状態（Redux）を参照する。
// スライドはブラウザの横スクロール（scroll-snap）で並べる。スワイプで中身が指に合わせて動き、
// 縦の操作はページのスクロール、タップはグラフの金額表示としてブラウザがそのまま扱う
export default function AppCarousel({
  children,
}: {
  children: React.ReactNode;
}) {
  const slides = React.Children.toArray(children);
  const last = Math.max(0, slides.length - 1);
  const scroller = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState(0);
  // 一覧の初期表示で全カードの全グラフを描かないよう、表示中と隣のスライドだけ描く。一度描いたスライドは残す
  const [rendered, setRendered] = useState<ReadonlySet<number>>(
    () => new Set([0, 1]),
  );
  // 順番を待っている、隣のスライドを描く処理
  const pendingNeighbors = useRef<{
    draw: () => void;
    leaveQueue: () => void;
  }>(undefined);
  // マウスを重ねる・タップする・フォーカスする・触れている間は自動切替を止める
  const [pausedBy, setPausedBy] = useState({
    hover: false,
    focus: false,
    touch: false,
  });
  const settledIndex = useRef(0);
  const autoScrolling = useRef(false);
  const touchStart = useRef<{
    x: number;
    y: number;
    scrollLeft: number;
  } | null>(null);
  const settleTimer = useRef<number>(undefined);
  const isAutoPlay = useSelector(
    (state: RootState) => state.autoPlayStatus.isAutoPlay,
  );

  const pause = (reason: keyof typeof pausedBy, paused: boolean) =>
    setPausedBy((current) =>
      current[reason] === paused ? current : { ...current, [reason]: paused },
    );

  const addRendered = (from: number, to: number) => {
    const start = Math.max(0, from);
    const end = Math.min(last, to);
    setRendered((current) => {
      const next = new Set(current);
      for (let index = start; index <= end; index++) {
        next.add(index);
      }
      return next.size === current.size ? current : next;
    });
  };

  // 表示するスライドはすぐに描き、その隣は順番を待って描く。隣は見えていないうえ、
  // 自動切替では全カードが同時に切り替わるため、隣のグラフを全カードで一度に描くと画面が止まる
  const renderBetween = (from: number, to: number) => {
    const start = Math.min(from, to);
    const end = Math.max(from, to);
    addRendered(start, end);
    const neighborsRendered =
      (start === 0 || rendered.has(start - 1)) &&
      (end === last || rendered.has(end + 1));
    if (neighborsRendered) {
      return;
    }
    pendingNeighbors.current?.leaveQueue();
    const draw = () => {
      pendingNeighbors.current = undefined;
      flushSync(() => addRendered(start - 1, end + 1));
    };
    pendingNeighbors.current = { draw, leaveQueue: waitForTurn(draw) };
  };

  // 触れる・マウスを重ねる・フォーカスすると、スワイプやキー操作で隣のスライドが見えるため、順番を待たずに描く
  const drawNeighborsNow = () => {
    const pending = pendingNeighbors.current;
    pending?.leaveQueue();
    pending?.draw();
  };

  const scrollToSlide = (index: number) => {
    const element = scroller.current;
    if (!element) {
      return;
    }
    renderBetween(active, index);
    element.scrollTo({ left: index * element.clientWidth, behavior: 'smooth' });
  };

  const handleScroll = () => {
    const element = scroller.current;
    if (!element || element.clientWidth === 0) {
      return;
    }
    const index = Math.min(
      last,
      Math.max(0, Math.round(element.scrollLeft / element.clientWidth)),
    );
    setActive(index);
    renderBetween(index, index);
    window.clearTimeout(settleTimer.current);
    settleTimer.current = window.setTimeout(() => {
      if (index !== settledIndex.current && !autoScrolling.current) {
        trackEvent('analysis_interaction', {
          interaction_type: 'chart_navigation',
          chart_type: chartTypes[index],
        });
      }
      settledIndex.current = index;
      autoScrolling.current = false;
    }, scrollSettleDelay);
  };

  // ナビボタン・自動切替・スワイプは、端では反対の端へ移る
  const previous = active === 0 ? last : active - 1;
  const following = active === last ? 0 : active + 1;

  // ブラウザは端より外へスクロールしないため、端で外側へのスワイプだけをここで判定する。
  // 縦のスクロールで移らないよう、横の動きが縦より大きいときに限る
  const handleTouchEnd = (event: React.TouchEvent<HTMLDivElement>) => {
    pause('touch', false);
    const start = touchStart.current;
    touchStart.current = null;
    const touch = event.changedTouches[0];
    if (!start || !touch) {
      return;
    }
    const dx = touch.clientX - start.x;
    const dy = touch.clientY - start.y;
    if (Math.abs(dx) < edgeSwipeDistance || Math.abs(dx) <= Math.abs(dy)) {
      return;
    }
    const element = event.currentTarget;
    const maxScrollLeft = element.scrollWidth - element.clientWidth;
    if (dx > 0 && start.scrollLeft <= 1) {
      scrollToSlide(last);
    } else if (dx < 0 && start.scrollLeft >= maxScrollLeft - 1) {
      scrollToSlide(0);
    }
  };
  const paused = pausedBy.hover || pausedBy.focus || pausedBy.touch;
  useEffect(() => {
    if (!isAutoPlay || paused || last === 0) {
      return;
    }
    // 表示中のスライドが変わるたびに待ち直し、手動で切り替えた直後に自動で進まないようにする
    const timer = window.setTimeout(() => {
      autoScrolling.current = true;
      scrollToSlide(following);
    }, autoPlayInterval);
    return () => window.clearTimeout(timer);
  }, [isAutoPlay, paused, active, last]);

  useEffect(
    () => () => {
      window.clearTimeout(settleTimer.current);
      pendingNeighbors.current?.leaveQueue();
    },
    [],
  );

  return (
    <Box
      position="relative"
      onMouseEnter={() => {
        pause('hover', true);
        drawNeighborsNow();
      }}
      onMouseLeave={() => pause('hover', false)}
      onFocus={() => {
        pause('focus', true);
        drawNeighborsNow();
      }}
      onBlur={() => pause('focus', false)}
    >
      <Box
        ref={scroller}
        onScroll={handleScroll}
        onTouchStart={(event) => {
          autoScrolling.current = false;
          pause('touch', true);
          drawNeighborsNow();
          // 2本指（拡大操作）は端のスワイプとして扱わない
          const touch = event.touches[0];
          touchStart.current =
            event.touches.length === 1
              ? {
                  x: touch.clientX,
                  y: touch.clientY,
                  scrollLeft: event.currentTarget.scrollLeft,
                }
              : null;
        }}
        onTouchEnd={handleTouchEnd}
        onTouchCancel={() => {
          touchStart.current = null;
          pause('touch', false);
        }}
        // 横に並べたスライドは一番高いスライドの高さにそろい、切り替えでカードの高さが変わって下のカードが動くことがない
        display="flex"
        sx={{
          overflowX: 'auto',
          // 縦にはスクロールさせない。グラフに触れて出たツールチップがはみ出しても、縦の操作はページのスクロールになる
          overflowY: 'hidden',
          scrollSnapType: 'x mandatory',
          // 端で横に引っぱっても、ブラウザの「戻る」操作にしない
          overscrollBehaviorX: 'contain',
          scrollbarWidth: 'none',
          '&::-webkit-scrollbar': { display: 'none' },
        }}
      >
        {slides.map((slide, index) => (
          <Box
            key={index}
            flex="0 0 100%"
            minWidth={0}
            // 勢いよくスワイプしても1枚ずつ進める
            sx={{ scrollSnapAlign: 'start', scrollSnapStop: 'always' }}
          >
            {rendered.has(index) && slide}
          </Box>
        ))}
      </Box>
      <Box
        height={navRowHeight}
        display="flex"
        alignItems="center"
        justifyContent="center"
      >
        {slides.map((_, index) => (
          <IconButton
            key={index}
            aria-label={`carousel indicator ${index + 1}`}
            aria-current={index === active ? 'true' : undefined}
            onClick={() => scrollToSlide(index)}
            sx={{
              p: 0,
              transition: '200ms',
              color: index === active ? '#494949' : '#afafaf',
              '&:hover, &:active': {
                color: index === active ? '#494949' : '#1f1f1f',
              },
            }}
          >
            <FiberManualRecordIcon sx={{ fontSize: 15 }} />
          </IconButton>
        ))}
      </Box>
      {(['prev', 'next'] as const).map((direction) => (
        <Box
          key={direction}
          position="absolute"
          bottom={0}
          height={navRowHeight}
          zIndex={1}
          {...(direction === 'next' ? { right: 0 } : { left: 0 })}
          sx={{
            '&:hover button': {
              backgroundColor: 'black',
              filter: 'brightness(120%)',
            },
          }}
        >
          <IconButton
            aria-label={direction === 'next' ? 'Next' : 'Previous'}
            onClick={() =>
              scrollToSlide(direction === 'next' ? following : previous)
            }
            sx={{
              mx: '10px',
              backgroundColor: '#494949',
              color: 'white',
              opacity: 0.2,
              transition: '200ms',
              '&:hover': { opacity: 0.6 },
            }}
          >
            {direction === 'next' ? (
              <NavigateNextIcon />
            ) : (
              <NavigateBeforeIcon />
            )}
          </IconButton>
        </Box>
      ))}
    </Box>
  );
}
