import { mergeFinancialReports } from './apolloClient';

describe('mergeFinancialReports（無限スクロールの結果連結）', () => {
  const page = (prefix: string, size: number) =>
    Array.from({ length: size }, (_, i) => `${prefix}${i}`);

  it('次ページはリスト末尾に連結される', () => {
    const merged = mergeFinancialReports(page('a', 30), page('b', 30), 30);
    expect(merged).toHaveLength(60);
    expect(merged[30]).toBe('b0');
  });

  it('同じoffsetを二重に取得しても重複せず、後続ページは保持される', () => {
    const existing = [...page('a', 30), ...page('b', 30)];
    const merged = mergeFinancialReports(existing, page('A', 30), 0);
    expect(merged).toHaveLength(60);
    expect(merged[0]).toBe('A0');
    expect(merged[30]).toBe('b0'); // 2ページ目は消えない
  });

  it('offsetが手元のリストより先でも歯抜けを作らず末尾に詰める（lengthと実件数を乖離させない）', () => {
    const merged = mergeFinancialReports(page('a', 30), page('c', 30), 60);
    expect(merged).toHaveLength(60);
    expect(merged.every((item) => item !== undefined)).toBe(true);
    expect(merged[30]).toBe('c0');
  });

  it('初回取得（existingなし）はそのまま返す', () => {
    expect(mergeFinancialReports(undefined, page('a', 5), 0)).toHaveLength(5);
  });
});
