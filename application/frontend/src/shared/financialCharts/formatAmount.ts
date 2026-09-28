// 金額（円）の表示用フォーマット。APIから受け取る金額は円のまま扱う。
//
// 有報の開示慣行（百万円未満切捨て）に合わせて百万円単位で表示する。円のまま出すと
// 「2,150,180,000円」のように桁が読めないため。
// 百万円未満の金額（千円単位で開示する小規模企業の無形固定資産・投資CFなど）は
// 「0百万円」にすると開示があるのに無いように見えるため、千円単位で出して
// 情報を落とさない（開示値は千円の倍数なので切捨てで桁落ちしない）
const YEN_PER_MILLION = 1_000_000;
const YEN_PER_THOUSAND = 1_000;
const millionNumber = new Intl.NumberFormat('ja-JP', {
  maximumFractionDigits: 6,
});

// Math.trunc は負の小数を -0 にする（-0.4 → -0 → "-0" と表示される）ため +0 で正の0に正規化する
const truncate = (value: number): number => Math.trunc(value) + 0;

export function formatAmount(yen: number): string {
  if (yen === 0) {
    return '0円';
  }
  if (Math.abs(yen) >= YEN_PER_MILLION) {
    return `${truncate(yen / YEN_PER_MILLION).toLocaleString()}百万円`;
  }
  return `${truncate(yen / YEN_PER_THOUSAND).toLocaleString()}千円`;
}

// CFグラフは単位を外に表示するため、ラベルを百万円単位の数値だけに揃える。
// 百万円未満も小数で残し、データがある値を0と誤表示しない。
export function formatAmountInMillions(yen: number): string {
  return millionNumber.format(yen / YEN_PER_MILLION);
}
