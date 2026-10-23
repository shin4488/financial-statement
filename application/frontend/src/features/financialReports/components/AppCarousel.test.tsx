import React from 'react';
import { Provider } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import AppCarousel from './AppCarousel';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';
import { trackEvent } from '@/plugins/firebase/analytics';

vi.mock('@/plugins/firebase/analytics', async (original) => ({
  ...(await original<typeof import('@/plugins/firebase/analytics')>()),
  trackEvent: vi.fn(),
}));

const slideWidth = 300;
const slideNames = ['BS', 'PL', 'CF', 'フリーCF', 'ROE・ROA'];

// jsdomは横スクロールしないため、スライド幅とscrollToをブラウザの代わりに与える
beforeEach(() => {
  vi.useFakeTimers();
  Object.defineProperty(HTMLElement.prototype, 'clientWidth', {
    configurable: true,
    get: () => slideWidth,
  });
  Object.defineProperty(HTMLElement.prototype, 'scrollWidth', {
    configurable: true,
    get: () => slideWidth * slideNames.length,
  });
  HTMLElement.prototype.scrollTo = function (
    options?: ScrollToOptions | number,
  ) {
    scrollTo(this, typeof options === 'object' ? options.left ?? 0 : 0);
  };
});

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.mocked(trackEvent).mockClear();
  delete (HTMLElement.prototype as Partial<HTMLElement>).scrollTo;
});

function scrollTo(element: Element, left: number) {
  Object.defineProperty(element, 'scrollLeft', {
    configurable: true,
    value: left,
  });
  fireEvent.scroll(element);
}

function renderCarousel(isAutoPlay = false) {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay } },
  });
  render(
    <Provider store={store}>
      <AppCarousel>
        {slideNames.map((name) => (
          <div key={name}>{name}</div>
        ))}
      </AppCarousel>
    </Provider>,
  );
  // スライドを横に並べてスクロールする要素
  return screen.getByText('BS').parentElement?.parentElement as HTMLElement;
}

// 指を1本置いて動かし、離す
function swipe(target: Element, dx: number, dy = 0) {
  fireEvent.touchStart(target, { touches: [{ clientX: 200, clientY: 300 }] });
  fireEvent.touchEnd(target, {
    touches: [],
    changedTouches: [{ clientX: 200 + dx, clientY: 300 + dy }],
  });
}

// スクロールの吸着が終わるまで待つ
function settle() {
  act(() => {
    vi.advanceTimersByTime(200);
  });
}

function currentSlide() {
  const current = screen
    .getAllByRole('button', { name: /carousel indicator/ })
    .findIndex((button) => button.getAttribute('aria-current') === 'true');
  return slideNames[current];
}

// 手動で切り替えると、切替先のグラフが計測される（docs/analytics の analysis_interaction）
function navigatedCharts() {
  return vi
    .mocked(trackEvent)
    .mock.calls.map(([, params]) => params?.chart_type);
}

it('スワイプで止まった位置のスライドを表示中とし、途中の位置では計測せず止まった位置で1回だけ計測する', () => {
  const scroller = renderCarousel();
  scrollTo(scroller, 100);
  scrollTo(scroller, 200);
  scrollTo(scroller, 300);
  expect(navigatedCharts()).toEqual([]);
  settle();
  expect(currentSlide()).toBe('PL');
  expect(navigatedCharts()).toEqual(['pl']);

  scrollTo(scroller, 140);
  scrollTo(scroller, 0);
  settle();
  expect(currentSlide()).toBe('BS');
  expect(navigatedCharts()).toEqual(['pl', 'bs']);
});

it('スワイプが途中で戻り、同じスライドに止まったときは計測しない', () => {
  const scroller = renderCarousel();
  scrollTo(scroller, 200);
  scrollTo(scroller, 0);
  settle();
  expect(currentSlide()).toBe('BS');
  expect(navigatedCharts()).toEqual([]);
});

it('ナビボタンは隣のスライドへ、端では反対の端へ移る', () => {
  renderCarousel();
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  settle();
  fireEvent.click(screen.getByRole('button', { name: 'Previous' }));
  settle();
  fireEvent.click(screen.getByRole('button', { name: 'Previous' }));
  settle();
  expect(currentSlide()).toBe('ROE・ROA');
  fireEvent.click(screen.getByRole('button', { name: 'Next' }));
  settle();
  expect(navigatedCharts()).toEqual(['pl', 'bs', 'indicators', 'bs']);
});

it('インジケータを押すと、そのスライドへ移る', () => {
  renderCarousel();
  fireEvent.click(screen.getByRole('button', { name: 'carousel indicator 3' }));
  settle();
  expect(currentSlide()).toBe('CF');
  expect(navigatedCharts()).toEqual(['cf']);
});

it('自動切替は6秒ごとに次へ進み、最後の次は先頭に戻る。手動の切替としては計測しない', () => {
  renderCarousel(true);
  for (const expected of ['PL', 'CF', 'フリーCF', 'ROE・ROA', 'BS']) {
    act(() => {
      vi.advanceTimersByTime(6000);
    });
    settle();
    expect(currentSlide()).toBe(expected);
  }
  expect(navigatedCharts()).toEqual([]);
});

it('触れている間とマウスを重ねている間は、自動切替を止める', () => {
  const scroller = renderCarousel(true);
  fireEvent.touchStart(scroller);
  act(() => {
    vi.advanceTimersByTime(6000);
  });
  expect(currentSlide()).toBe('BS');
  fireEvent.touchEnd(scroller);
  act(() => {
    vi.advanceTimersByTime(6000);
  });
  settle();
  expect(currentSlide()).toBe('PL');

  fireEvent.mouseEnter(scroller);
  act(() => {
    vi.advanceTimersByTime(12000);
  });
  expect(currentSlide()).toBe('PL');
});

it('最初は表示中と隣のスライドだけを描き、表示が進むとその隣も描く', () => {
  const scroller = renderCarousel();
  expect(slideNames.filter((name) => screen.queryByText(name))).toEqual([
    'BS',
    'PL',
  ]);
  scrollTo(scroller, slideWidth);
  settle();
  expect(slideNames.filter((name) => screen.queryByText(name))).toEqual([
    'BS',
    'PL',
    'CF',
  ]);
});

it('先頭で右へ、最後で左へスワイプすると、反対の端へ移る', () => {
  const scroller = renderCarousel();
  swipe(scroller, 80);
  settle();
  expect(currentSlide()).toBe('ROE・ROA');
  swipe(scroller, -80);
  settle();
  expect(currentSlide()).toBe('BS');
  expect(navigatedCharts()).toEqual(['indicators', 'bs']);
});

it('端でも、横の動きが50px未満か、縦の動き以下なら反対の端へ移らない', () => {
  const scroller = renderCarousel();
  swipe(scroller, 49);
  swipe(scroller, 80, 80);
  swipe(scroller, 80, -80);
  settle();
  expect(navigatedCharts()).toEqual([]);
  swipe(scroller, 50);
  settle();
  expect(navigatedCharts()).toEqual(['indicators']);
});

it('端以外から始めたスワイプや、端から内側へのスワイプでは、反対の端へ移らない', () => {
  const scroller = renderCarousel();
  // 内側へのスワイプはブラウザがスクロールするため、ここでは何もしない
  swipe(scroller, -80);
  settle();
  expect(navigatedCharts()).toEqual([]);
  scrollTo(scroller, slideWidth);
  settle();
  // 2枚目から右へ大きく動かし、指を離すまでに先頭まで戻っても、最後へは移らない
  fireEvent.touchStart(scroller, {
    touches: [{ clientX: 200, clientY: 300 }],
  });
  scrollTo(scroller, 0);
  fireEvent.touchEnd(scroller, {
    touches: [],
    changedTouches: [{ clientX: 600, clientY: 300 }],
  });
  settle();
  expect(currentSlide()).toBe('BS');
  expect(navigatedCharts()).toEqual(['pl', 'bs']);
});

it('2本指の操作は、端でも反対の端へ移らない', () => {
  const scroller = renderCarousel();
  fireEvent.touchStart(scroller, {
    touches: [
      { clientX: 200, clientY: 300 },
      { clientX: 260, clientY: 300 },
    ],
  });
  fireEvent.touchEnd(scroller, {
    changedTouches: [{ clientX: 300, clientY: 300 }],
  });
  settle();
  expect(navigatedCharts()).toEqual([]);
});
