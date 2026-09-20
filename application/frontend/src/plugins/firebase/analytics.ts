import { initializeApp } from 'firebase/app';
import { siteOrigin, siteRoutes } from '@/features/siteLayout/siteRoutes';
import {
  Analytics,
  initializeAnalytics as createAnalytics,
  isSupported,
  logEvent,
} from 'firebase/analytics';

// Firebaseが発行する公開設定。Measurement Protocolの秘密キーはここに置かない。
const firebaseConfig = {
  apiKey: 'AIzaSyAsyg8vgDV2r4uH5iZSpxvhxqqRQgzjbZc',
  authDomain: 'flaza-17d8c.firebaseapp.com',
  projectId: 'flaza-17d8c',
  storageBucket: 'flaza-17d8c.appspot.com',
  messagingSenderId: '282295142919',
  appId: '1:282295142919:web:5dbe9007f48a49ad70f8a2',
  measurementId: 'G-ZCJ8NTQ6KY',
};

export type ProductEvent =
  | 'page_view'
  | 'search_submit'
  | 'report_result'
  | 'report_load_more'
  | 'analysis_interaction'
  | 'outbound_click';

export type ProductParams = {
  search_mode?: 'browse' | 'stock' | 'cash_flow' | 'combined';
  result_status?: 'success' | 'empty' | 'error';
  result_count?: number;
  unavailable_count?: number;
  stock_count?: number;
  interaction_type?: 'chart_navigation' | 'autoplay_on' | 'autoplay_off';
  chart_type?: 'bs' | 'pl' | 'cf' | 'indicators';
  link_domain?: 'kabutan.jp';
};

let analytics: Promise<Analytics | null> | undefined;

function campaignParams() {
  const query = new URLSearchParams(window.location.search);
  return query.get('utm_source') === 'investee_extension'
    ? {
        campaign_source: 'investee_extension',
        campaign_medium: 'referral',
        campaign_name: 'compare',
      }
    : {};
}

// URLには任意の入力が含まれ得る。ページ分類だけを送り、検索語・query/hashは送らない。
export function analyticsPage(pathname: string): string {
  return (Object.values(siteRoutes) as string[]).includes(pathname)
    ? pathname
    : '/';
}

export function initializeAnalytics(): Promise<Analytics | null> {
  if (!import.meta.env.PROD || window.location.hostname !== 'investee.info') {
    return Promise.resolve(null);
  }
  analytics ??= isSupported()
    .then((supported) =>
      supported
        ? createAnalytics(initializeApp(firebaseConfig), {
            config: {
              ...campaignParams(),
              send_page_view: false,
              page_location: `${siteOrigin}${analyticsPage(
                window.location.pathname,
              )}`,
              page_referrer: safeReferrer(),
              allow_google_signals: false,
              allow_ad_personalization_signals: false,
            },
          })
        : null,
    )
    .catch(() => null);
  return analytics;
}

function safeReferrer(): string {
  try {
    return document.referrer ? new URL(document.referrer).origin : '';
  } catch {
    return '';
  }
}

// 計測失敗を画面の描画・検索・リンク遷移に伝播させない。
export function trackEvent(
  name: ProductEvent,
  params: ProductParams = {},
): void {
  const page = analyticsPage(window.location.pathname);
  void initializeAnalytics()
    .then((instance) => {
      if (!instance) {
        return;
      }
      logEvent(instance, name as string, {
        ...params,
        analytics_version: '2',
        page_location: `${siteOrigin}${page}`,
        page_referrer: safeReferrer(),
        page_title: page === '/' ? '企業分析' : page.slice(1),
      });
    })
    .catch(() => undefined);
}
