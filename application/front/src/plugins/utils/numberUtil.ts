import StringUtil from '@/plugins/utils/stringUtil';

export class NumberUtil {
  static toNumberOrDefault(
    value: string | undefined | null,
    defaultValue = 0,
  ): number {
    return StringUtil.isEmpty(value) ? defaultValue : Number(value);
  }
}
