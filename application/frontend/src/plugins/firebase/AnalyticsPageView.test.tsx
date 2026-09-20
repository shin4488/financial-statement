// @vitest-environment jsdom
import React from 'react';
import { fireEvent, render, cleanup } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { MemoryRouter, useNavigate } from 'react-router-dom';
import AnalyticsPageView from './AnalyticsPageView';
import { trackEvent } from './analytics';
vi.mock('./analytics', async (original) => ({
  ...(await original<typeof import('./analytics')>()),
  trackEvent: vi.fn(),
}));
afterEach(cleanup);

function Navigation() {
  const navigate = useNavigate();
  return (
    <>
      <button onClick={() => navigate('/?stock-codes=7203')}>検索</button>
      <button onClick={() => navigate('/guide')}>ガイド</button>
    </>
  );
}

it('counts a page once in StrictMode and does not inflate views when searching', () => {
  const view = render(
    <React.StrictMode>
      <MemoryRouter>
        <AnalyticsPageView />
        <Navigation />
      </MemoryRouter>
    </React.StrictMode>,
  );
  expect(trackEvent).toHaveBeenCalledTimes(1);
  fireEvent.click(view.getByText('検索'));
  expect(trackEvent).toHaveBeenCalledTimes(1);
  fireEvent.click(view.getByText('ガイド'));
  expect(trackEvent).toHaveBeenCalledTimes(2);
});
