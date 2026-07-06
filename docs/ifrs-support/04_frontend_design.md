# フロントエンド設計

## 1. データ取得（GraphQL）

`src/pages/financialStatementList/service.ts` のクエリに以下を追加する:

```graphql
accountingStandard
ifrsBalanceSheet {
  amount { currentAsset nonCurrentAsset currentLiability nonCurrentLiability equity }
  ratio  { currentAsset nonCurrentAsset currentLiability nonCurrentLiability equity }
}
ifrsProfitLoss {
  amount { revenue costOfSales sellingGeneralExpense otherIncomeExpenseNet profitLossBeforeTax }
  ratio  { revenue costOfSales sellingGeneralExpense otherIncomeExpenseNet profitLossBeforeTax }
}
```

- `cashFlow` は既存のまま共用（IFRS行にも同じ形で値が入る）。
- `npm run codegen`（graphql-codegen）で `__generated__` を再生成する。
- `state.ts` の `FinancialStatement` に `accountingStandard` と `ifrsBalanceSheet` / `ifrsProfitLoss`
  （どちらも nullable）を追加し、`mapFinancialStatementFromResponseToState` でマッピングする。
  日本基準行では ifrs 側が null、IFRS行では既存の `balanceSheet` / `profitLoss` が null になる。

## 2. コンポーネント構成（高凝集・疎結合）

既存コンポーネントは変更せず、IFRS専用のチャートを新設する。
共通の描画基盤 `FinancialStatementBarChart`（recharts の BarChart ラッパー）と
`WaterFlowBarChart`（CF用）、`ChartAlternative`（表示不能時の代替表示）は再利用する。

```
src/components/
  balanceSheetBarChart/        # 既存（日本基準）: 変更なし
  profitLossBarChart/          # 既存（日本基準）: 変更なし
  cashFlowBarChart/            # 既存: IFRSでもそのまま使用（変更なし）
  ifrsBalanceSheetBarChart/    # 新規
    IfrsBalanceSheetBarChart.tsx
    chartData.ts
    props.ts
  ifrsProfitLossBarChart/      # 新規
    IfrsProfitLossBarChart.tsx
    chartData.ts
    props.ts
```

一覧ページ（`FinancialStatementList.tsx`）のカード描画で `accountingStandard` により分岐する:

```tsx
{statement.accountingStandard === 'ifrs' ? (
  <>
    <IfrsBalanceSheetBarChart amount={...} ratio={...} />
    <IfrsProfitLossBarChart amount={...} ratio={...} />
  </>
) : (
  <>
    <BalanceSheetBarChart amount={...} ratio={...} />
    <ProfitLossBarChart amount={...} ratio={...} />
  </>
)}
<CashFlowBarChart ... />   {/* 共通 */}
```

分岐はこの1箇所のみ。各チャートコンポーネント内部に他基準の知識を持ち込まない。
カード上に会計基準バッジ（「IFRS」等）を表示すると閲覧者が構成の違いを理解しやすい（推奨・任意）。

## 3. IfrsBalanceSheetBarChart（連結財政状態計算書）

既存 `BalanceSheetBarChart` と同じ2本積み上げ棒（借方/貸方）+ 債務超過時3本目の構成。

- 借方（1本目）: 流動資産 / 非流動資産 の2段積み上げ
- 貸方（2本目）: 流動負債 / 非流動負債 / 資本 の3段積み上げ
- ラベル: `流動資産: xx%` のように既存と同じ形式（ratioを表示、tooltipでamount円表示）
- 債務超過（`equity < 0`）: 既存 `BalanceSheetBarChart` の `isInsolvency` / `blanckForInsolvencyAmount`
  と同一パターンで3本目に資本のマイナスを表示する
- データ検証（既存 `hasInvalidData` 相当）:
  `流動資産 + 非流動資産` と `流動負債 + 非流動負債 + 資本` の差が1割超なら `ChartAlternative` を表示。
  いずれかの必須値が null の場合も同様
- 凡例日本語: 流動資産 / 非流動資産 / 流動負債 / 非流動負債 / 資本

`chartData.ts` の型（既存の命名規約に合わせる）:

```ts
interface Debit {
  currentAssetAmount: number;
  nonCurrentAssetAmount: number;
  currentAssetRatio: number;
  nonCurrentAssetRatio: number;
}
interface Credit {
  currentLiabilityAmount: number;
  nonCurrentLiabilityAmount: number;
  equityAmount?: number;
  currentLiabilityRatio: number;
  nonCurrentLiabilityRatio: number;
  equityRatio?: number;
}
interface MinusEquity { blanckForInsolvencyAmount: number; equityAmount: number; equityRatio: number; }
export type IfrsBalanceSheetChart = [Debit, Credit, MinusEquity?];
```

## 4. IfrsProfitLossBarChart（連結損益計算書）

IFRSには経常利益・特別損益がなく、売上総利益・営業利益は企業により開示有無が異なるため、
**収益 → 税引前利益** の骨格で表示する。バックエンドから受け取る5値の符号により積み上げ先を決める:

- 借方（費用側）に積むもの:
  - 売上原価（null なら段を出さない）
  - 販売費及び一般管理費（null なら段を出さない）
  - その他損益純額 `otherIncomeExpenseNet` が **負** の場合: `その他費用（純額）` として絶対値を積む
  - 税引前利益 `profitLossBeforeTax` が **正** の場合: `税引前利益` として積む
- 貸方（収益側）に積むもの:
  - 収益 `revenue`
  - `otherIncomeExpenseNet` が **正** の場合: `その他収益（純額）` として積む
  - `profitLossBeforeTax` が **負** の場合: `税引前損失` として絶対値を積む
    （既存 `ProfitLossBarChart` が営業損失を貸方に積むのと同じパターン）

これで借方合計 = 貸方合計が常に成立する（otherIncomeExpenseNet がその差分を埋める導出値のため）。

- 実例: 武田薬品（2026/3期）= 借方[原価1.57兆, 販管費1.08兆, その他費用純額1.99兆] / 貸方[収益4.51兆, 税引前損失0.14兆]
- 実例: 三菱商事（2026/3期）= 借方[原価17.26兆, 販管費1.24兆, 税引前利益1.10兆] / 貸方[収益18.92兆, その他収益純額0.68兆]
- ratio は収益=100 とした売上収益比（既存PLチャートと同じ流儀）
- 凡例日本語: 収益 / 売上原価 / 販売費及び一般管理費 / その他収益（純額）/ その他費用（純額）/ 税引前利益 / 税引前損失
- データ検証: `revenue` または `profitLossBeforeTax` が null なら `ChartAlternative` を表示

```ts
interface Debit {
  costOfSalesAmount?: number;
  sellingGeneralExpenseAmount?: number;
  otherExpenseNetAmount?: number;      // otherIncomeExpenseNet < 0 のとき絶対値
  profitBeforeTaxAmount?: number;      // profitLossBeforeTax >= 0 のとき
  // ...各Ratio
}
interface Credit {
  revenueAmount: number;
  otherIncomeNetAmount?: number;       // otherIncomeExpenseNet >= 0 のとき
  lossBeforeTaxAmount?: number;        // profitLossBeforeTax < 0 のとき絶対値
  // ...各Ratio
}
export type IfrsProfitLossChart = [Debit, Credit];
```

## 5. CF・フィルタ機能

- CFチャート: IFRSでも「期首残高 → 営業CF → 投資CF → 財務CF → 期末残高」のウォーターフォール構造は
  同一のため、既存 `CashFlowBarChart` / `WaterFlowBarChart` をそのまま使う。変更なし。
- CF符号フィルタ（営業+/-・投資+/-・財務+/- の検索条件）: フロントは変更不要。
  バックエンド側でIFRS行も条件対象になる（03参照）。
