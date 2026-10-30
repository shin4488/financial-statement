import React from 'react';
import { cleanup, render } from '@testing-library/react';
import {
  colorByRole,
  StackedBarChart,
  type Segment,
  type StackChart,
} from '@/shared/financialCharts';

beforeEach(() => {
  vi.stubGlobal(
    'ResizeObserver',
    class {
      constructor(
        private callback: (
          entries: { contentRect: { width: number; height: number } }[],
        ) => void,
      ) {}
      observe() {
        this.callback([{ contentRect: { width: 400, height: 400 } }]);
      }
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
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
