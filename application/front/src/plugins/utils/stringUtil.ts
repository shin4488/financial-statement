export default class StringUtil {
  static isEmpty(value: string | undefined | null): boolean {
    return value === undefined || value === null || value === '';
  }

  static toBlankIfEmpty(value: string | undefined | null): string {
    return StringUtil.isEmpty(value) ? '' : (value as string);
  }
}
