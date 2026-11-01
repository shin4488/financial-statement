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
  vi.useFakeTimers({
    toFake: [
      'setTimeout',
      'clearTimeout',
      'requestAnimationFrame',
      'cancelAnimationFrame',
    ],
  });
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
  // 描く順番待ちの処理を最後まで進め、次のテストに持ち越さない
  vi.runAllTimers();
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
    .getAllByRole('button', { name: /^\d番目のグラフ$/ })
    .findIndex((button) => button.getAttribute('aria-current') === 'true');
  return slideNames[current];
}

// 手動で切り替えると、切替先のグラフが計測される（docs/analytics の analysis_interaction）
function navigatedCharts() {
  return vi
    .mocked(trackEvent)
    .mock.calls.map(([, params]) => params?.chart_type);
}

it('切替のボタンは、インジケータを「1番目のグラフ」〜「5番目のグラフ」、前後のボタンを「前のグラフ」「次のグラフ」という名前で伝える', () => {
  renderCarousel();
  const names = [
    ...slideNames.map((_, index) => `${index + 1}番目のグラフ`),
    '前のグラフ',
    '次のグラフ',
  ];
  // 名前ごとにボタンが1つだけあり、ほかの名前のボタンはない
  for (const name of names) {
    screen.getByRole('button', { name });
  }
  expect(screen.getAllByRole('button')).toHaveLength(names.length);
});

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
  fireEvent.click(screen.getByRole('button', { name: '次のグラフ' }));
  settle();
  fireEvent.click(screen.getByRole('button', { name: '前のグラフ' }));
  settle();
  fireEvent.click(screen.getByRole('button', { name: '前のグラフ' }));
  settle();
  expect(currentSlide()).toBe('ROE・ROA');
  fireEvent.click(screen.getByRole('button', { name: '次のグラフ' }));
  settle();
  expect(navigatedCharts()).toEqual(['pl', 'bs', 'indicators', 'bs']);
});

it('インジケータを押すと、そのスライドへ移る', () => {
  renderCarousel();
  fireEvent.click(screen.getByRole('button', { name: '3番目のグラフ' }));
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

it('触れている間と、スライドの中身にマウスを重ねている間は、自動切替を止める', () => {
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

  fireEvent.pointerEnter(screen.getByText('PL'), { pointerType: 'mouse' });
  act(() => {
    vi.advanceTimersByTime(12000);
  });
  expect(currentSlide()).toBe('PL');
});

it.each([
  ['スライドの余白', () => screen.getByText('BS').parentElement as HTMLElement],
  ['切替のボタン', () => screen.getByRole('button', { name: '次のグラフ' })],
])('%sにマウスを重ねているだけでは、自動切替を止めない', (_, target) => {
  renderCarousel(true);
  fireEvent.pointerEnter(target(), { pointerType: 'mouse' });
  act(() => {
    vi.advanceTimersByTime(6000);
  });
  settle();
  expect(currentSlide()).toBe('PL');
});

it.each([
  [
    'スライドの余白へ移る',
    (content: HTMLElement) =>
      fireEvent.pointerOver(content.parentElement as HTMLElement, {
        pointerType: 'mouse',
      }),
  ],
  [
    'カルーセルの外へ出る',
    (content: HTMLElement) =>
      fireEvent.pointerLeave(content, { pointerType: 'mouse' }),
  ],
])(
  'マウスがスライドの中身から離れると、そこから6秒後に自動切替を再開する（%s）',
  (_, leave) => {
    renderCarousel(true);
    const content = screen.getByText('BS');
    fireEvent.pointerEnter(content, { pointerType: 'mouse' });
    act(() => {
      vi.advanceTimersByTime(5000);
    });
    leave(content);
    act(() => {
      vi.advanceTimersByTime(5000);
    });
    expect(currentSlide()).toBe('BS');
    act(() => {
      vi.advanceTimersByTime(1000);
    });
    settle();
    expect(currentSlide()).toBe('PL');
  },
);

it('フォーカスしている間は、自動切替を止める', () => {
  renderCarousel(true);
  act(() => screen.getByRole('button', { name: '次のグラフ' }).focus());
  act(() => {
    vi.advanceTimersByTime(12000);
  });
  expect(currentSlide()).toBe('BS');
});

// タップと、その後にブラウザが続けて出すイベント（スマホのブラウザの動き）。
// タッチのポインタが重なり、互換のためのマウスのイベントが続き、押した要素にフォーカスが当たってからクリックになる
function tap(target: HTMLElement) {
  fireEvent.touchStart(target);
  fireEvent.touchEnd(target);
  fireEvent.pointerEnter(target, { pointerType: 'touch' });
  fireEvent.mouseEnter(target);
  act(() => target.focus());
  fireEvent.click(target);
}

it('スライドをタップした後は、ブラウザが続けて出すマウスのイベントやフォーカスでは止めず、自動切替を続ける', () => {
  const scroller = renderCarousel(true);
  // グラフにはフォーカスが当たるため、タップしたスライドにフォーカスできるようにする
  scroller.tabIndex = 0;
  tap(scroller);
  act(() => {
    vi.advanceTimersByTime(6000);
  });
  settle();
  expect(currentSlide()).toBe('PL');
});

it('前後のボタンをタップした後も、自動切替を続ける', () => {
  renderCarousel(true);
  tap(screen.getByRole('button', { name: '次のグラフ' }));
  settle();
  expect(currentSlide()).toBe('PL');
  act(() => {
    vi.advanceTimersByTime(6000);
  });
  settle();
  expect(currentSlide()).toBe('CF');
});

it('タップから1秒以上たってから当たったフォーカスでは、自動切替を止める', () => {
  // jsdomのイベントの時刻（timeStamp）はDate.nowから作られるため、Dateも偽の時計にして進める
  vi.useFakeTimers({
    toFake: [
      'setTimeout',
      'clearTimeout',
      'requestAnimationFrame',
      'cancelAnimationFrame',
      'Date',
    ],
  });
  const scroller = renderCarousel(true);
  fireEvent.touchStart(scroller);
  fireEvent.touchEnd(scroller);
  vi.setSystemTime(Date.now() + 1000);
  act(() => screen.getByRole('button', { name: '次のグラフ' }).focus());
  act(() => {
    vi.advanceTimersByTime(12000);
  });
  expect(currentSlide()).toBe('BS');
});

// 中身を描いたスライド
function renderedSlides() {
  return slideNames.filter((name) => screen.queryByText(name));
}

it('最初は表示中のスライドだけを描き、隣は見えていないため順番を待って描く。表示が進んだときも、その隣は順番を待って描く', () => {
  const scroller = renderCarousel();
  expect(renderedSlides()).toEqual(['BS']);
  act(() => {
    vi.advanceTimersByTime(0);
  });
  expect(renderedSlides()).toEqual(['BS', 'PL']);
  scrollTo(scroller, slideWidth);
  expect(renderedSlides()).toEqual(['BS', 'PL']);
  act(() => {
    vi.advanceTimersByTime(20);
  });
  expect(renderedSlides()).toEqual(['BS', 'PL', 'CF']);
});

it('中身を描けない間は隣のスライドを描かず、描けるようになったら隣を順番を待って描く', () => {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay: false } },
  });
  const carousel = (deferred: boolean) => (
    <Provider store={store}>
      <AppCarousel deferred={deferred}>
        {slideNames.map((name) => (
          <div key={name}>{name}</div>
        ))}
      </AppCarousel>
    </Provider>
  );
  const { rerender } = render(carousel(true));
  act(() => {
    vi.advanceTimersByTime(20);
  });
  expect(renderedSlides()).toEqual(['BS']);

  rerender(carousel(false));
  expect(renderedSlides()).toEqual(['BS']);
  act(() => {
    vi.advanceTimersByTime(0);
  });
  expect(renderedSlides()).toEqual(['BS', 'PL']);
});

it('インジケータで離れたスライドへ移るときは、途中と移り先のスライドを順番を待たずに描く', () => {
  renderCarousel();
  fireEvent.click(screen.getByRole('button', { name: '4番目のグラフ' }));
  expect(renderedSlides()).toEqual(['BS', 'PL', 'CF', 'フリーCF']);
});

it('触れる・マウスを重ねる・フォーカスすると、隣のスライドを順番を待たずに描く', () => {
  const interactions: ((scroller: HTMLElement) => void)[] = [
    (scroller) => fireEvent.touchStart(scroller),
    (scroller) => fireEvent.pointerEnter(scroller, { pointerType: 'mouse' }),
    () => act(() => screen.getByRole('button', { name: '次のグラフ' }).focus()),
  ];
  for (const interact of interactions) {
    const scroller = renderCarousel();
    scrollTo(scroller, slideWidth);
    interact(scroller);
    expect(renderedSlides()).toEqual(['BS', 'PL', 'CF']);
    cleanup();
  }
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
