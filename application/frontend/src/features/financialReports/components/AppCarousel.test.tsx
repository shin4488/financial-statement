import React from 'react';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { configureStore } from '@reduxjs/toolkit';
import { Provider } from 'react-redux';
import autoPlayStatusReducer from '@/store/slices/autoPlayStatusSlice';
import AppCarousel from './AppCarousel';

vi.mock('@/plugins/firebase/analytics', () => ({ trackEvent: vi.fn() }));

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

const slideNames = ['BS', 'PL', 'CF', 'FCF', '指標'];

function renderCarousel(isAutoPlay: boolean) {
  const store = configureStore({
    reducer: { autoPlayStatus: autoPlayStatusReducer },
    preloadedState: { autoPlayStatus: { isAutoPlay } },
  });
  render(
    <Provider store={store}>
      <AppCarousel>
        {slideNames.map((name) => (
          <button key={name}>{name}</button>
        ))}
      </AppCarousel>
    </Provider>,
  );
}

// inertの付いたスライドは、ブラウザがTabの移動先と支援技術の読み上げから外す
function operableSlides() {
  return slideNames.filter(
    (name) => screen.getByText(name).closest('[inert]') === null,
  );
}

describe('AppCarousel', () => {
  it('makes only the first slide operable on first render', () => {
    renderCarousel(false);
    expect(operableSlides()).toEqual(['BS']);
  });

  it('excludes the slide that was just left, which stays rendered off-screen', () => {
    renderCarousel(false);
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(operableSlides()).toEqual(['PL']);
  });

  it('follows the shown slide when wrapping from the last slide to the first', () => {
    renderCarousel(false);
    fireEvent.click(
      screen.getByRole('button', { name: 'carousel indicator 5' }),
    );
    expect(operableSlides()).toEqual(['指標']);
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(operableSlides()).toEqual(['BS']);
  });

  it('follows the shown slide when autoplay advances it', () => {
    vi.useFakeTimers();
    renderCarousel(true);
    act(() => {
      vi.advanceTimersByTime(6000);
    });
    expect(operableSlides()).toEqual(['PL']);
  });
});
