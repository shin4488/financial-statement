import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router-dom';
import { analyticsPage, trackEvent } from './analytics';

export default function AnalyticsPageView() {
  const { pathname } = useLocation();
  const previous = useRef<string>();
  useEffect(() => {
    const page = analyticsPage(pathname);
    if (previous.current === page) {
      return;
    }
    previous.current = page;
    trackEvent('page_view');
  }, [pathname]);
  return null;
}
