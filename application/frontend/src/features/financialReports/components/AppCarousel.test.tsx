import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import { cleanup, fireEvent, render } from '@testing-library/react';
import AppCarousel from './AppCarousel';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';
import { trackEvent } from '@/plugins/firebase/analytics';

vi.mock('@/plugins/firebase/analytics', async (original) => ({
  ...(await original<typeof import('@/plugins/firebase/analytics')>()),
  trackEvent: vi.fn(),
}));

afterEach(() => {
  cleanup();
  vi.mocked(trackEvent).mockClear();
});

// 自動切替は止め、手動の切替だけが起きるようにする
function renderCarousel() {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay: false } },
  });
  const view = render(
    <Provider store={store}>
      <AppCarousel>
        {['BS', 'PL', 'CF', 'フリーCF', 'ROE・ROA'].map((name) => (
          <div key={name}>{name}</div>
        ))}
      </AppCarousel>
    </Provider>,
  );
  return view.container.firstElementChild as HTMLElement;
}

function swipe(target: HTMLElement, dx: number, dy: number) {
  fireEvent.touchStart(target, { touches: [{ clientX: 200, clientY: 300 }] });
  fireEvent.touchEnd(target, {
    touches: [],
    changedTouches: [{ clientX: 200 + dx, clientY: 300 + dy }],
  });
}

// 手動で切り替えると、切替先のグラフが計測される（docs/analytics の analysis_interaction）
function navigatedCharts() {
  return vi
    .mocked(trackEvent)
    .mock.calls.map(([, params]) => params?.chart_type);
}

it('左へスワイプすると次、右へスワイプすると前のグラフへ切り替わる', () => {
  const carousel = renderCarousel();
  swipe(carousel, -80, 0);
  swipe(carousel, -80, 0);
  swipe(carousel, 80, 0);
  expect(navigatedCharts()).toEqual(['pl', 'cf', 'pl']);
});

it('先頭から右へスワイプすると、ボタン操作と同じく最後のグラフへ移る', () => {
  swipe(renderCarousel(), 80, 0);
  expect(navigatedCharts()).toEqual(['indicators']);
});

it('横の移動が50px未満なら切り替えない', () => {
  const carousel = renderCarousel();
  swipe(carousel, -49, 0);
  expect(navigatedCharts()).toEqual([]);
  swipe(carousel, -50, 0);
  expect(navigatedCharts()).toEqual(['pl']);
});

it('縦の移動が横の半分を超える（縦スクロールの）ときは切り替えない', () => {
  const carousel = renderCarousel();
  swipe(carousel, -80, 41);
  swipe(carousel, -80, -200);
  expect(navigatedCharts()).toEqual([]);
  swipe(carousel, -80, 40);
  expect(navigatedCharts()).toEqual(['pl']);
});

it('2本指の操作や、ブラウザに中断された操作では切り替えない', () => {
  const carousel = renderCarousel();
  fireEvent.touchStart(carousel, {
    touches: [
      { clientX: 200, clientY: 300 },
      { clientX: 260, clientY: 300 },
    ],
  });
  fireEvent.touchEnd(carousel, {
    changedTouches: [{ clientX: 100, clientY: 300 }],
  });
  fireEvent.touchStart(carousel, {
    touches: [{ clientX: 200, clientY: 300 }],
  });
  fireEvent.touchCancel(carousel);
  fireEvent.touchEnd(carousel, {
    changedTouches: [{ clientX: 100, clientY: 300 }],
  });
  expect(navigatedCharts()).toEqual([]);
});
