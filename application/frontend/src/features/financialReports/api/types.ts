// コンポーネントのpropsに使う型はcodegenの生成型から導出し、手書きしない
// （スキーマ変更時に型ズレが起きない）。チャート部分は構造が一致するため、
// 共有チャートキット（src/shared/financialCharts）の構造的型にそのまま代入できる
import type { FinancialReportsQuery } from '@/__generated__/graphql';

export type FinancialReport = FinancialReportsQuery['financialReports'][number];
