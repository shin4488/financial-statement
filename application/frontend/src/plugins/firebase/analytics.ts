import { initializeApp } from 'firebase/app';
import {
  Analytics,
  AnalyticsCallOptions,
  getAnalytics,
  logEvent,
} from 'firebase/analytics';

// Firebaseコンソールが発行するWebアプリ設定。公開前提の識別子で秘匿情報ではない
const firebaseConfig = {
  apiKey: 'AIzaSyAsyg8vgDV2r4uH5iZSpxvhxqqRQgzjbZc',
  authDomain: 'flaza-17d8c.firebaseapp.com',
  projectId: 'flaza-17d8c',
  storageBucket: 'flaza-17d8c.appspot.com',
  messagingSenderId: '282295142919',
  appId: '1:282295142919:web:5dbe9007f48a49ad70f8a2',
  measurementId: 'G-ZCJ8NTQ6KY',
};

type AnalyticsEventParams = {
  [key: string]: unknown;
  content_type?: string | undefined;
  item_id?: string | undefined;
};

let analytics: Analytics | null = null;

// 初回呼び出しでFirebaseごと初期化する（アプリ起動時に一度呼んでおく）
export function initializeAnalytics(): Analytics {
  analytics = analytics ?? getAnalytics(initializeApp(firebaseConfig));
  return analytics;
}

export function logClickEvent(
  eventParams?: AnalyticsEventParams,
  options?: AnalyticsCallOptions,
) {
  logEvent(initializeAnalytics(), 'click', eventParams, options);
}
