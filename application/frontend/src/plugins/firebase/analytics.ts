import FirebaseInitialization from './initialization';
import {
  Analytics,
  AnalyticsCallOptions,
  getAnalytics,
  logEvent,
} from 'firebase/analytics';

type AnalyticsEventParams = {
  [key: string]: unknown;
  content_type?: string | undefined;
  item_id?: string | undefined;
};

export default class FirebaseAnalytics {
  private static analytics: Analytics | null = null;

  static getAnalytics(): Analytics {
    this.analytics =
      this.analytics ??
      getAnalytics(new FirebaseInitialization().appInstance());
    return this.analytics;
  }

  private static logEvent(
    eventName: string,
    eventParams?: AnalyticsEventParams,
    options?: AnalyticsCallOptions | undefined,
  ) {
    logEvent(
      this.analytics ?? FirebaseAnalytics.getAnalytics(),
      eventName,
      eventParams,
      options,
    );
  }

  static logLoadMoreStatementsEvent(
    eventParams?: AnalyticsEventParams,
    options?: AnalyticsCallOptions | undefined,
  ) {
    FirebaseAnalytics.logEvent('load_more_statements', eventParams, options);
  }

  static logClickEvent(
    eventParams?: AnalyticsEventParams,
    options?: AnalyticsCallOptions | undefined,
  ) {
    FirebaseAnalytics.logEvent('click', eventParams, options);
  }
}
