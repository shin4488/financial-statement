import { CashFlowTypeValue, cashFlowTypeRequestMap } from '@/constants/values';

// 検索条件はURLクエリ（例: /?stock-codes=7203,391A&cash-flow-type=healthy）が正。
// URLの解釈が送信側（GraphQL変数化）と表示側（チップ・セレクト）で別々だと
// 「チップの表示と検索結果が食い違う」事故になるため、パースをここへ1本化する

// サーバ側バリデーション（stockCodes最大100件）と対:
// 細工URLで巨大な配列を送ってエラー画面になるのを防ぐ
export const maxStockCodes = 100;

export function parseStockCodes(searchParams: URLSearchParams): string[] {
  // 証券コードは大文字で保存されている（英数字コード対応後の391A等）。
  // 小文字・空白混じりの入力や共有URLでも検索できるよう正規化する
  return (
    searchParams
      .get('stock-codes')
      ?.split(',')
      .map((code) => code.trim().toUpperCase())
      .filter(Boolean)
      .slice(0, maxStockCodes) ?? []
  );
}

export function parseCashFlowType(
  searchParams: URLSearchParams,
): CashFlowTypeValue {
  const cfType = (searchParams.get('cash-flow-type') ??
    'none') as CashFlowTypeValue;
  // hasOwnPropertyで引く: 素の[]アクセスだとcash-flow-typeが"constructor"等のとき
  // Object.prototypeのメンバーが返り、noneへのフォールバックが効かないため
  return Object.prototype.hasOwnProperty.call(cashFlowTypeRequestMap, cfType)
    ? cfType
    : 'none';
}
