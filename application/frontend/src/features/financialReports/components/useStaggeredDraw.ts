import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { flushSync } from 'react-dom';

// 置いた時点で、画面とその下の画面の高さの0.3倍までにある要素は、最初の表示から描く。
// 追加で読み込んだ要素は画面の下端のすぐ下に並び、スクロールで次のフレームに見えてくることがあるため。
// 広げるほど、最初の表示までに描く要素が増える
const drawAtOnceScreens = 1.3;

// 描く順番を待っている要素
const waiting: (() => void)[] = [];
let drawing = false;

function drawNext() {
  const draw = waiting.shift();
  if (!draw) {
    drawing = false;
    return;
  }
  draw();
  // 描いた要素に続く更新を画面に出してから、次の要素を描く
  requestAnimationFrame(() => setTimeout(drawNext));
}

function waitForTurn(draw: () => void) {
  waiting.push(draw);
  if (!drawing) {
    drawing = true;
    setTimeout(drawNext);
  }
  return () => {
    const index = waiting.indexOf(draw);
    if (index >= 0) {
      waiting.splice(index, 1);
    }
  };
}

// 要素の中身を描いてよいかを返す。全要素を一度に描くと、その間は画面が止まるため、
// 画面の近くの要素は最初の表示から描き、ほかの要素は置いた順に1フレームに1つずつ描く。
// 順番を待つ間に画面に見えてきた要素は、順番を待たずに描く
export function useStaggeredDraw<T extends Element>() {
  const ref = useRef<T>(null);
  const [drawn, setDrawn] = useState(false);
  useLayoutEffect(() => {
    const rect = ref.current?.getBoundingClientRect();
    if (
      rect &&
      rect.bottom > 0 &&
      rect.top < window.innerHeight * drawAtOnceScreens
    ) {
      setDrawn(true);
    }
  }, []);
  useEffect(() => {
    const element = ref.current;
    if (drawn || !element) {
      return;
    }
    const draw = () => flushSync(() => setDrawn(true));
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        draw();
      }
    });
    observer.observe(element);
    const leaveQueue = waitForTurn(draw);
    return () => {
      observer.disconnect();
      leaveQueue();
    };
  }, [drawn]);
  return [ref, drawn] as const;
}
