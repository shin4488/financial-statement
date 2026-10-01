import React from 'react';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { StackedBarChart } from './StackedBarChart';
import type { Segment, StackChart } from './types';

const segment = (
  key: string,
  amount: number,
  ratio: number | null = amount,
): Segment => ({
  key,
  label: key,
  amount: amount * 1_000_000,
  signedAmount: amount * 1_000_000,
  ratio,
  colorRole: 'asset1',
});
const chart: StackChart = {
  renderable: true,
  bars: [
    {
      label: '借方',
      segments: [
        segment('large', 50),
        segment('small', 1),
        segment('wrapped', 5),
        { ...segment('loss', 44, -44), signedAmount: -44_000_000 },
        segment('zero', 0),
      ],
    },
    {
      label: '貸方',
      segments: [
        segment('longLabel', 99),
        { ...segment('spacer', 1, null), colorRole: 'spacer' },
      ],
    },
  ],
};

let containerWidth = 300;
const originals = [
  [HTMLElement.prototype, 'clientWidth'],
  [HTMLElement.prototype, 'clientHeight'],
  [HTMLElement.prototype, 'offsetWidth'],
  [HTMLElement.prototype, 'offsetHeight'],
  [HTMLElement.prototype, 'getBoundingClientRect'],
  [SVGElement.prototype, 'getBBox'],
  [globalThis, 'ResizeObserver'],
] as const;
let descriptors: (PropertyDescriptor | undefined)[];

beforeEach(() => {
  containerWidth = 300;
  descriptors = originals.map(([target, name]) =>
    Object.getOwnPropertyDescriptor(target, name),
  );
  // jsdomにないブラウザのレイアウト計測を固定値で補う。描画と表示判定は本体を使う。
  Object.defineProperties(HTMLElement.prototype, {
    clientWidth: { configurable: true, get: () => containerWidth },
    clientHeight: { configurable: true, get: () => 400 },
    offsetWidth: { configurable: true, get: () => containerWidth },
    offsetHeight: { configurable: true, get: () => 400 },
    getBoundingClientRect: {
      configurable: true,
      value: () => ({
        x: 0,
        y: 0,
        left: 0,
        top: 0,
        right: containerWidth,
        bottom: 400,
        width: containerWidth,
        height: 400,
      }),
    },
  });
  Object.defineProperty(SVGElement.prototype, 'getBBox', {
    configurable: true,
    value: function (this: SVGElement) {
      const text = this.textContent ?? '';
      return {
        x: 0,
        y: 0,
        width: text.includes('longLabel') ? 180 : 80,
        height: text.includes('wrapped') ? 36 : 18,
      };
    },
  });
  Object.defineProperty(globalThis, 'ResizeObserver', {
    configurable: true,
    value: class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  });
});

afterEach(() => {
  cleanup();
  originals.forEach(([target, name], index) => {
    const descriptor = descriptors[index];
    if (descriptor) {
      Object.defineProperty(target, name, descriptor);
    } else {
      Reflect.deleteProperty(target, name);
    }
  });
});

function labelVisibility(container: HTMLElement, prefix: string) {
  const label = Array.from(container.querySelectorAll('.recharts-label')).find(
    (element) => element.textContent?.startsWith(prefix),
  );
  return label?.parentElement?.getAttribute('visibility');
}

it('収まる区画は従来のラベルを残し、小さい区画・折り返し・ゼロ高のラベルを隠す', () => {
  const { container } = render(<StackedBarChart chart={chart} />);
  expect(labelVisibility(container, 'large:')).toBe('visible');
  expect(labelVisibility(container, 'loss:')).toBe('visible');
  expect(labelVisibility(container, 'small:')).toBe('hidden');
  expect(labelVisibility(container, 'wrapped:')).toBe('hidden');
  expect(labelVisibility(container, 'zero:')).toBe('hidden');
  expect(container.textContent?.replace(/\s/g, '')).toContain('loss:-44%');
  expect(container.textContent).not.toContain('spacer:');
});

it('横に収まらない文字を隠し、幅が広がると表示を戻す（バーの値・形は変えない）', () => {
  const { container, rerender } = render(<StackedBarChart chart={chart} />);
  expect(labelVisibility(container, 'longLabel:')).toBe('hidden');
  const before = Array.from(
    container.querySelectorAll('.recharts-bar-rectangle path'),
  ).map((element) => element.getAttribute('d'));
  rerender(
    <StackedBarChart
      chart={{
        ...chart,
        bars: chart.bars.map((bar) => ({
          ...bar,
          segments: bar.segments.map((s) =>
            s.key === 'longLabel' ? { ...s, label: 'shortLabel' } : s,
          ),
        })),
      }}
    />,
  );
  expect(labelVisibility(container, 'shortLabel:')).toBe('visible');
  expect(
    Array.from(container.querySelectorAll('.recharts-bar-rectangle path')).map(
      (element) => element.getAttribute('d'),
    ),
  ).toEqual(before);
  containerWidth = 600;
  // ResponsiveContainerを再計測させる。実ブラウザのresizeは表示検証でも確認する。
  rerender(<StackedBarChart key="wide" chart={chart} />);
  expect(labelVisibility(container, 'longLabel:')).toBe('visible');
});

it('隠した科目もツールチップに値と割合を残し、負数・ゼロ・spacerを区別する', () => {
  const { container } = render(<StackedBarChart chart={chart} />);
  const mouse = new MouseEvent('mousemove', {
    bubbles: true,
    clientX: 80,
    clientY: 200,
  });
  // 古いjsdomでもReact/Rechartsへブラウザと同じページ座標を渡す。
  Object.defineProperties(mouse, {
    pageX: { value: 80 },
    pageY: { value: 200 },
  });
  fireEvent(container.querySelector('.recharts-wrapper')!, mouse);
  expect(screen.getByText('small : 1百万円 (1%)')).toBeTruthy();
  expect(screen.getByText('wrapped : 5百万円 (5%)')).toBeTruthy();
  expect(screen.getByText('loss : -44百万円 (-44%)')).toBeTruthy();
  expect(screen.getByText('zero : 0円 (0%)')).toBeTruthy();
  expect(screen.queryByText(/spacer :/)).toBeNull();
});

it('欠損・未対応の説明を維持し、空データでもラベルを作らない', () => {
  const { container, rerender } = render(
    <StackedBarChart
      chart={{ renderable: false, note: 'この形式は未対応です', bars: [] }}
    />,
  );
  expect(screen.getByText('この形式は未対応です')).toBeTruthy();
  expect(container.querySelector('.recharts-label')).toBeNull();
  rerender(<StackedBarChart chart={{ renderable: true, bars: [] }} />);
  expect(container.querySelector('.recharts-label')).toBeNull();
});
