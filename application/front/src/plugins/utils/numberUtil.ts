export class NumberUtil {
  static toNumberOrDefault(
    value: string | number | undefined | null,
    defaultValue = 0,
  ): number {
    return value === undefined || value === null ? defaultValue : Number(value);
  }
}
