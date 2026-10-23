import React, { useRef } from 'react';
import { useSelector } from 'react-redux';
import Carousel from 'react-material-ui-carousel';
import { RootState } from '@/store/store';
import { trackEvent, ProductParams } from '@/plugins/firebase/analytics';

// ナビボタンはカルーセル下端の帯に置かれる。インジケータ行を同じ高さにしないと、ボタンが行からスライド側へはみ出し、幅の狭い画面ではチャートの下端に重なる
const navRowHeight = 40;
// 縦スクロール中の指のぶれで切り替わらないよう、横に一定以上、かつ縦の2倍以上動いたときだけスワイプとみなす
const swipeMinDistance = 50;

// カルーセルの操作感（6秒の自動切替・スライド・常時ナビ表示・スワイプ）を全カードで統一するラッパー。
// 自動切替のON/OFFだけ画面共通の状態（Redux）を参照する
export default function AppCarousel({
  children,
}: {
  children: React.ReactNode;
}) {
  const manualNavigation = useRef(false);
  const touchStart = useRef<{ x: number; y: number } | null>(null);
  const buttonProps = {
    style: { opacity: 0.2 },
    onClickCapture: () => {
      manualNavigation.current = true;
    },
  };
  const indicatorProps = {
    className: '',
    onClickCapture: buttonProps.onClickCapture,
  };
  const isAutoPlay = useSelector(
    (state: RootState) => state.autoPlayStatus.isAutoPlay,
  );
  // ライブラリのswipeは、指が横に少しでもずれていれば縦スクロールの途中でも切り替わる。そのため使わず、指を離した位置で判定する
  const handleTouchEnd = (event: React.TouchEvent<HTMLDivElement>) => {
    const start = touchStart.current;
    touchStart.current = null;
    const touch = event.changedTouches[0];
    if (!start || !touch) {
      return;
    }
    const dx = touch.clientX - start.x;
    const dy = touch.clientY - start.y;
    if (Math.abs(dx) < swipeMinDistance || Math.abs(dx) < Math.abs(dy) * 2) {
      return;
    }
    // 切替の向きのアニメーションと手動切替の計測をボタン操作と揃えるため、ナビボタンを押して切り替える
    event.currentTarget
      .querySelector<HTMLButtonElement>(
        `button[aria-label="${dx < 0 ? 'Next' : 'Previous'}"]`,
      )
      ?.click();
  };
  return (
    <div
      onTouchStart={(event) => {
        // 2本指（拡大操作）はスワイプとして扱わない
        touchStart.current =
          event.touches.length === 1
            ? { x: event.touches[0].clientX, y: event.touches[0].clientY }
            : null;
      }}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={() => {
        touchStart.current = null;
      }}
    >
      <Carousel
        onChange={(now, previous) => {
          if (manualNavigation.current && now !== previous) {
            const chartTypes: ProductParams['chart_type'][] = [
              'bs',
              'pl',
              'cf',
              'fcf',
              'indicators',
            ];
            trackEvent('analysis_interaction', {
              interaction_type: 'chart_navigation',
              chart_type: chartTypes[now ?? 0],
            });
          }
          manualNavigation.current = false;
        }}
        indicatorContainerProps={{
          style: {
            marginTop: 0,
            height: navRowHeight,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          },
        }}
        indicatorIconButtonProps={indicatorProps}
        autoPlay={isAutoPlay}
        swipe={false}
        interval={6000}
        stopAutoPlayOnHover
        animation="slide"
        duration={100}
        navButtonsAlwaysVisible
        navButtonsWrapperProps={{
          style: { top: 'auto', bottom: 0, height: navRowHeight },
        }}
        navButtonsProps={buttonProps}
      >
        {children}
      </Carousel>
    </div>
  );
}
