export class EnvUtil {
  static isDevelopment(): boolean {
    return process.env.NODE_ENV === 'development';
  }
}
