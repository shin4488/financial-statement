// クエリ文字列を変更したら `npm run compile`（graphql-codegen）で型を再生成すること。
// フラグメントを使わない理由: client-presetのfragment maskingを避け、
// 生成型をそのままコンポーネントのpropsに流せるようにするため
import { gql } from '@/__generated__';

export const FINANCIAL_REPORTS_QUERY = gql(`
  query FinancialReports(
    $limit: Int!, $offset: Int!, $stockCodes: [String!],
    $operatingCfSign: CashFlowSign, $investingCfSign: CashFlowSign, $financingCfSign: CashFlowSign
  ) {
    financialReports(
      limit: $limit, offset: $offset, stockCodes: $stockCodes,
      operatingCfSign: $operatingCfSign, investingCfSign: $investingCfSign, financingCfSign: $financingCfSign
    ) {
      id
      stockCode
      companyName
      fiscalYearStartDate
      fiscalYearEndDate
      accountingStandard
      consolidationType
      balanceSheet {
        renderable
        note
        bars {
          label
          segments { key label amount signedAmount ratio colorRole tooltipLabel }
        }
      }
      profitLoss {
        renderable
        note
        bars {
          label
          segments { key label amount signedAmount ratio colorRole tooltipLabel }
        }
      }
      cashFlow {
        renderable
        note
        steps { key label amount kind colorRole }
      }
    }
  }
`);
