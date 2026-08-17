import { formatAmount } from './formatAmount';

describe('formatAmount', () => {
  it('百万円以上は百万円単位・百万円未満切捨てで表示する', () => {
    expect(formatAmount(2_150_180_000)).toBe('2,150百万円');
    expect(formatAmount(1_000_000)).toBe('1百万円');
    expect(formatAmount(-1_499_999)).toBe('-1百万円');
  });

  it('百万円未満は千円単位で表示し、0百万円に潰さない', () => {
    expect(formatAmount(162_000)).toBe('162千円');
    expect(formatAmount(-823_000)).toBe('-823千円');
    expect(formatAmount(999_999)).toBe('999千円');
  });

  it('負の端数を切り捨てても "-0" にならない', () => {
    expect(formatAmount(-400)).toBe('0千円');
  });

  it('0は0円', () => {
    expect(formatAmount(0)).toBe('0円');
  });
});
