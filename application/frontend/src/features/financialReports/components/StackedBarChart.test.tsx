import React from 'react';
import { cleanup, render } from '@testing-library/react';
import {
  colorByRole,
  StackedBarChart,
  type Segment,
  type StackChart,
} from '@/shared/financialCharts';

beforeEach(() => {
  // jsdomは要素の大きさを計算しないため、グラフを描く枠の大きさを渡す
  vi.spyOn(HTMLElement.prototype, 'clientWidth', 'get').mockReturnValue(400);
  vi.spyOn(HTMLElement.prototype, 'clientHeight', 'get').mockReturnValue(400);
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function seg(
  key: string,
  amount: number,
  colorRole: string,
  ratio: number | null = amount,
): Segment {
  return { key, label: key, amount, signedAmount: amount, ratio, colorRole };
}

const assets = { label: '借方', segments: [seg('assets', 100, 'asset1')] };
const solvent: StackChart = {
  renderable: true,
  bars: [
    assets,
    {
      label: '貸方',
      segments: [
        seg('liabilities', 60, 'liability1'),
        seg('equity', 40, 'equity'),
      ],
    },
  ],
};
// 債務超過の純資産は、3本目のバーで詰め物（spacer）の下に積む
const insolvent: StackChart = {
  renderable: true,
  bars: [
    assets,
    { label: '貸方', segments: [seg('liabilities', 120, 'liability1')] },
    {
      label: '債務超過',
      segments: [
        seg('spacer', 100, 'spacer', null),
        seg('equity', 20, 'equity'),
      ],
    },
  ],
};

function verticalSpan(container: HTMLElement, fill: string) {
  const path = [...container.querySelectorAll('.recharts-bar-rectangle path')]
    .filter((p) => p.getAttribute('fill') === fill)
    .pop();
  const y = Number(path?.getAttribute('y'));
  const height = Number(path?.getAttribute('height'));
  return { top: Math.min(y, y + height), bottom: Math.max(y, y + height) };
}

it('表示中に積み上げの列が増えても、APIの並びのとおり上から積む', () => {
  const { container, rerender } = render(
    <StackedBarChart chart={solvent} height={400} />,
  );

  rerender(<StackedBarChart chart={insolvent} height={400} />);

  const spacer = verticalSpan(container, colorByRole.spacer);
  const equity = verticalSpan(container, colorByRole.equity);
  expect(equity.top).toBeCloseTo(spacer.bottom);
  cleanup();
  const fresh = render(<StackedBarChart chart={insolvent} height={400} />);
  expect(verticalSpan(fresh.container, colorByRole.equity)).toEqual(equity);
});

it('グラフはTabの移動先にならない', () => {
  const { container } = render(
    <StackedBarChart chart={solvent} height={400} />,
  );

  expect(
    [...container.querySelectorAll('[tabindex]')].filter(
      (element) => (element as HTMLElement | SVGElement).tabIndex >= 0,
    ),
  ).toEqual([]);
});

it('区分の棒とラベルを宣言した順に重ね、後の区分の棒を前の区分のラベルより前に描く', () => {
  const { container } = render(
    <StackedBarChart chart={solvent} height={400} />,
  );

  // SVGは文書の順に重ねて描く
  const fill = (element: Element) =>
    element.getAttribute('fill') ??
    element.querySelector('[fill]')?.getAttribute('fill');
  const painted = [
    ...container.querySelectorAll('.recharts-bar-rectangle path, text'),
  ].map((element) =>
    element.tagName === 'text'
      ? `label:${element.textContent}`
      : `bar:${fill(element)}`,
  );
  expect(painted).toEqual([
    `bar:${colorByRole.asset1}`,
    'label:assets: 100%',
    `bar:${colorByRole.liability1}`,
    'label:liabilities: 60%',
    `bar:${colorByRole.equity}`,
    'label:equity: 40%',
  ]);
});
