// financialReports APIのチャート構造と1:1対応する構造的型。
// codegen生成型をそのまま使わない理由: このディレクトリはブラウザ拡張と共有するため、
// アプリごとのcodegen設定・生成物に依存させない（構造が一致していれば代入可能）
// null許容フィールドを `?:` にしている理由: GraphQL codegenはnull許容フィールドを
// optionalとして生成するため、生成型をそのまま代入できるようにする
export interface Segment {
  key: string; // バー内で一意。Reactのkey・recharts dataKeyに使う
  label: string; // 表示ラベル。フロントに科目辞書を持たない意図でAPIが直接返す
  amount: number; // 描画高さ。常に >= 0
  signedAmount: number; // 実値。ツールチップはこちらを表示（赤字は負で届く）
  ratio?: number | null; // %。null/undefinedは「表示しない」（spacer等）
  colorRole: string; // colorRoles.tsのキー
}

export interface StackBar {
  label: string;
  segments: Segment[];
}

export interface StackChart {
  renderable: boolean;
  note?: string | null;
  bars: StackBar[];
}

export interface WaterfallStep {
  key: string;
  label: string;
  amount: number; // こちらは符号付き（増減をそのまま表す）
  kind: string; // 'balance'=残高（0起点） / 'flow'=増減（累積位置から浮かせる）
  // 'cashIncrease' | 'cashDecrease'。optionalなのはフィールド追加前のAPI・古いクエリの
  // 呼び出し元（コピー先の拡張など）でも動かすため。無ければ符号から補う
  colorRole?: string | null;
}

export interface WaterfallChart {
  renderable: boolean;
  note?: string | null;
  steps: WaterfallStep[];
}
