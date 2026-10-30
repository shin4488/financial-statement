import React from 'react';

// グラフを描く枠の大きさを、レイアウトの直後（画面に出す前）に測る。測った大きさをグラフに渡し、1回で描くため。
// 非表示のカルーセル項目は0×0になる
export function useChartSize<T extends HTMLElement>(measuring: boolean) {
  const ref = React.useRef<T>(null);
  const [size, setSize] = React.useState({ width: 0, height: 0 });

  React.useLayoutEffect(() => {
    const element = ref.current;
    if (!measuring || !element) {
      return;
    }
    const updateSize = () => {
      const width = element.clientWidth;
      const height = element.clientHeight;
      setSize((current) =>
        current.width === width && current.height === height
          ? current
          : { width, height },
      );
    };
    const observer = new ResizeObserver(updateSize);
    observer.observe(element);
    updateSize();
    return () => observer.disconnect();
  }, [measuring]);

  return [ref, size] as const;
}
