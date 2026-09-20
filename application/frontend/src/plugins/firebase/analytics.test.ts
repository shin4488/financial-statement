import { afterEach, describe, expect, it, vi } from 'vitest';

vi.mock('firebase/app', () => ({ initializeApp: vi.fn(() => ({})) }));
vi.mock('firebase/analytics', () => ({
  initializeAnalytics: vi.fn(() => ({})),
  isSupported: vi.fn(async () => true),
  logEvent: vi.fn(),
}));

afterEach(() => {
  vi.unstubAllEnvs();
  vi.clearAllMocks();
  vi.resetModules();
});

describe('analytics isolation', () => {
  it('does not initialize Firebase on local or test builds', async () => {
    const { trackEvent, initializeAnalytics } = await import('./analytics');
    const sdk = await import('firebase/analytics');
    trackEvent('search_submit', { search_mode: 'stock' });
    expect(await initializeAnalytics()).toBeNull();
    expect(sdk.initializeAnalytics).not.toHaveBeenCalled();
    expect(sdk.logEvent).not.toHaveBeenCalled();
  });

  it('limits page names to public routes, never arbitrary paths or input', async () => {
    const { analyticsPage } = await import('./analytics');
    expect(analyticsPage('/guide')).toBe('/guide');
    expect(analyticsPage('/person@example.com')).toBe('/');
  });
});

it('uses sanitized production context and does not leak query strings', async () => {
  vi.stubEnv('PROD', true);
  vi.stubGlobal('window', {
    location: {
      hostname: 'investee.info',
      pathname: '/guide',
      search: '?email=private@example.com',
    },
  });
  vi.stubGlobal('document', {
    referrer: 'https://example.com/private?token=secret',
  });
  const { trackEvent, initializeAnalytics } = await import('./analytics');
  const sdk = await import('firebase/analytics');
  trackEvent('analysis_interaction', {
    chart_type: 'cf',
    interaction_type: 'chart_navigation',
  });
  await initializeAnalytics();
  await Promise.resolve();
  expect(sdk.logEvent).toHaveBeenCalledWith(
    expect.anything(),
    'analysis_interaction',
    {
      chart_type: 'cf',
      interaction_type: 'chart_navigation',
      analytics_version: '2',
      page_location: 'https://investee.info/guide',
      page_referrer: 'https://example.com',
      page_title: 'guide',
    },
  );
  expect(sdk.initializeAnalytics).toHaveBeenCalledWith(
    expect.anything(),
    expect.objectContaining({
      config: expect.objectContaining({ send_page_view: false }),
    }),
  );
  vi.unstubAllGlobals();
});
