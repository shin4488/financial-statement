import FirebaseInitialization from './initialization';
import {
  Analytics,
  AnalyticsCallOptions,
  getAnalytics,
  logEvent,
} from 'firebase/analytics';

export default class FirebaseAnalytics {
  private static analytics: Analytics | null = null;

  static getAnalytics(): Analytics {
    this.analytics =
      this.analytics ??
      getAnalytics(new FirebaseInitialization().appInstance());
    return this.analytics;
  }

  private static logEvent(
    evnetName: string,
    eventParams?:
      | {
          [key: string]: unknown;
          content_type?: string | undefined;
          item_id?: string | undefined;
        }
      | undefined,
    options?: AnalyticsCallOptions | undefined,
  ) {
    logEvent(
      this.analytics ?? FirebaseAnalytics.getAnalytics(),
      evnetName,
      eventParams,
      options,
    );
  }

  static logLoadMoreStatementsEvent(
    eventParams?:
      | {
          [key: string]: unknown;
          content_type?: string | undefined;
          item_id?: string | undefined;
        }
      | undefined,
    options?: AnalyticsCallOptions | undefined,
  ) {
    FirebaseAnalytics.logEvent('load_more_statements', eventParams, options);
  }

  static logClickEvent(
    eventParams?:
      | {
          [key: string]: unknown;
          content_type?: string | undefined;
          item_id?: string | undefined;
        }
      | undefined,
    options?: AnalyticsCallOptions | undefined,
  ) {
    FirebaseAnalytics.logEvent('click', eventParams, options);
  }
}
