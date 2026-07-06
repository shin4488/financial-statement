# バックエンド設計

## 1. XBRL読み取り層（Repository）

### 1-1. クラス構成

会計基準ごとの読み取り知識を基準別クラスに閉じ込める。

```
app/repositories/security_report/
  reader_repository.rb            # ヘッダ/DEI読取り + 会計基準に応じたReaderへの委譲（変更）
  readers/
    japan_gaap_statement_reader.rb  # 既存 SingleSecurityReportsReader を移設（ロジック変更なし）
    ifrs_statement_reader.rb        # 新規: jpigp_cor の連結財務諸表読取り
```

- `ReaderRepository#read` の責務: DEI・企業情報・会計年度の読み取り、会計基準の判定、各Readerの呼び出し。
- 戻り値（既存キーは維持し、IFRS時のみ `ifrs_consolidated_statement` を追加）:

```ruby
{
  edinet_code:, stock_code:, company_japanese_name:, company_english_name:,
  accounting_standard:, has_consolidated_financial_statement:,
  fiscal_year_start_date:, fiscal_year_end_date:, filing_date:,
  consolidated_inductory_code:, non_consolidated_inductory_code:,
  consolidated_statement: {...},        # 既存（日本基準連結）。IFRS企業では従来どおり実質空
  non_consolidated_statement: {...},    # 既存（日本基準単体）。IFRS企業でも取得できる（変更なし）
  ifrs_consolidated_statement: {...} | nil,  # accounting_standard == "ifrs" のときのみ
}
```

- 日本基準企業では `ifrs_consolidated_statement` は `nil`。IFRS企業でも `consolidated_statement` は
  既存ロジックのまま実行してよい（factが無いだけで害はない）。分岐は「IFRSのときだけIFRS Readerを追加実行」の1箇所に留める。

### 1-2. `IfrsStatementReader` の読み取り仕様

- コンテキスト: BSは `CurrentYearInstant`、PL/CFは `CurrentYearDuration`、CF期首残高のみ `Prior1YearInstant`。
- **値が取れない場合は `nil` を返す**（`.to_i` で0にしない）。実装例:
  `text = @parser.extract_text(key: ...); text.nil? ? nil : text.to_i`
- 収益のようにタグが企業によって異なる科目は、**フォールバックリストの先頭から最初にヒットした値**を使う（既存の `net_sales` / `cost_of_sales` と同じパターン）。

| 保存カラム | XBRL要素の優先順位リスト |
|---|---|
| current_asset | `jpigp_cor:CurrentAssetsIFRS` |
| non_current_asset | `jpigp_cor:NonCurrentAssetsIFRS` |
| asset | `jpigp_cor:AssetsIFRS` |
| property_plant_and_equipment | `jpigp_cor:PropertyPlantAndEquipmentIFRS` |
| goodwill_and_intangible_asset | `jpigp_cor:GoodwillAndIntangibleAssetsIFRS` → なければ `jpigp_cor:GoodwillIFRS` + `jpigp_cor:IntangibleAssetsIFRS` の**合算**（両方nilならnil、片方のみでも合算値とする） |
| current_liability | `jpigp_cor:TotalCurrentLiabilitiesIFRS` → `jpigp_cor:CurrentLiabilitiesIFRS` |
| non_current_liability | `jpigp_cor:NonCurrentLabilitiesIFRS`（タクソノミ側タイポ。実タグ） → `jpigp_cor:NonCurrentLiabilitiesIFRS` |
| liability | `jpigp_cor:LiabilitiesIFRS` |
| equity_attributable_to_owners_of_parent | `jpigp_cor:EquityAttributableToOwnersOfParentIFRS` |
| non_controlling_interest | `jpigp_cor:NonControllingInterestsIFRS` |
| equity | `jpigp_cor:EquityIFRS` |
| revenue | `jpigp_cor:RevenueIFRS` → `jpigp_cor:Revenue2IFRS` → `jpigp_cor:NetSalesIFRS` → `jpigp_cor:SalesIFRS` → `jpigp_cor:OperatingRevenuesIFRS` → `jpcrp_cor:RevenueIFRSSummaryOfBusinessResults` |
| cost_of_sales | `jpigp_cor:CostOfSalesIFRS` |
| gross_profit | `jpigp_cor:GrossProfitIFRS` |
| selling_general_and_administrative_expense | `jpigp_cor:SellingGeneralAndAdministrativeExpensesIFRS` |
| operating_profit_loss | `jpigp_cor:OperatingProfitLossIFRS` |
| profit_loss_before_tax | `jpigp_cor:ProfitLossBeforeTaxIFRS` |
| income_tax_expense | `jpigp_cor:IncomeTaxExpenseIFRS` |
| profit_loss | `jpigp_cor:ProfitLossIFRS` |
| profit_loss_attributable_to_owners_of_parent | `jpigp_cor:ProfitLossAttributableToOwnersOfParentIFRS` |
| start_cash_flow_balance | `jpigp_cor:CashAndCashEquivalentsIFRS`（`Prior1YearInstant`） |
| operating_activity_cash_flow | `jpigp_cor:NetCashProvidedByUsedInOperatingActivitiesIFRS` |
| investing_activity_cash_flow | `jpigp_cor:NetCashProvidedByUsedInInvestingActivitiesIFRS`（Investment ではなく **Investing**） |
| financing_activity_cash_flow | `jpigp_cor:NetCashProvidedByUsedInFinancingActivitiesIFRS` |
| end_cash_flow_balance | `jpigp_cor:CashAndCashEquivalentsIFRS`（`CurrentYearInstant`） |

## 2. 取込層（SubscriberService）

`IndividualSubscriber#perform` の保存処理に以下を追加する（ダウンロード・展開・削除処理は変更なし）:

```ruby
security_report_result = create_security_report(security_report, company_id)  # 既存（戻り値からidを取る形に変更）
create_ifrs_financial_statement(security_report, security_report_result.last["id"])  # 新規
```

- `create_ifrs_financial_statement` は `security_report[:ifrs_consolidated_statement]` が `nil` なら何もしない。
- 保存は `IfrsFinancialStatement.upsert({security_report_id:, ...科目...}, unique_by: :security_report_id)`
  （修正有報の再取込対応。既存と同じ考え方）。
- `SecurityReport.upsert` は既存実装のままだが、`RETURNING` で id を取得して次の処理に渡す
  （`Company.upsert` で既にやっているのと同じ方法）。

## 3. 参照層（FetcherService / Model）

### 3-1. `SecurityReport` モデルのクエリ変更

現在 `where(accounting_standard: "japan_gaap")` で日本基準に絞っている箇所を IFRS も対象にする:

```ruby
.where(accounting_standard: ["japan_gaap", "ifrs"])
.eager_load(:ifrs_financial_statement)   # N+1回避
```

- IFRS有報で連結財務諸表がない（`ifrs_financial_statements` 行がない）ものは表示できないため除外する:
  `japan_gaap` または（`ifrs` かつ `ifrs_financial_statements.id IS NOT NULL`）という条件にする。
- **CF符号フィルタ**（`fetch_company_security_reports_with_cash_flow_condition`）は、会計基準ごとに参照カラムが異なる:
  - japan_gaap: 既存どおり `consolidated_* / non_consolidated_*` カラム
  - ifrs: `ifrs_financial_statements.operating_activity_cash_flow` 等
  - 既存の「連結あり→連結CF / 連結なし→単体CF」のOR条件に、「ifrs → ifrs_financial_statements のCF」の枝を1つ加える形で実装する。

### 3-2. Presenter の分割（FetcherService）

現在 `FetcherService` に日本基準の科目選択・比率計算がベタ書きされている。会計基準別に分離する:

```
app/services/security_report/
  fetcher_service.rb                 # クエリ実行と、会計基準による Presenter 振り分けのみ（薄くする）
  presenters/
    japan_gaap_presenter.rb          # 既存の整形・比率計算ロジックを移設（変更なし）
    ifrs_presenter.rb                # 新規
```

- 各Presenterは `#present(security_report)` で GraphQL 型に対応するハッシュを返す。
- 共通項目（id, 会計年度, 企業名, has_consolidated_financial_statement, 業種コード等）は
  基底クラスまたは共通メソッドで整形してよいが、**科目・比率の知識は各Presenterに閉じる**。

### 3-3. `IfrsPresenter` の計算仕様

比率は既存と同じく `truncate(3) * 100`（%値）。

**BS**（総資産 `asset` を分母とする）:

```
amount: current_asset, non_current_asset, current_liability, non_current_liability, equity
        (+ 参考: property_plant_and_equipment, goodwill_and_intangible_asset)
ratio:  current_asset_ratio = current_asset / asset
        non_current_asset_ratio = 1 - current_asset_ratio          # 端数吸収は既存と同じ考え方
        current_liability_ratio = current_liability / asset
        non_current_liability_ratio = non_current_liability / asset
        equity_ratio = equity >= 0 ? 1 - (current_liability_ratio + non_current_liability_ratio)
                                   : equity / asset                 # 債務超過時は既存と同じ扱い
```

**PL**: IFRSは営業利益・売上総利益の開示が任意のため、全企業で確実に取れる
`revenue`（収益）と `profit_loss_before_tax`（税引前利益）を骨格とし、差額を導出項目で埋める。

```
cost_of_sales_amount   = cost_of_sales（nilなら0扱いで導出計算し、amountとしてはnullを返す）
sga_amount             = selling_general_and_administrative_expense（同上）
other_income_expense_net = profit_loss_before_tax - (revenue - cost_of_sales - sga)
  # その他の営業損益・金融損益・持分法損益等の純額。
  # 正: 収益側（貸方）に積む / 負: 費用側（借方）に絶対値を積む
```

- 実測値での検算:
  - 武田: other_net = ▲1,992,272百万（費用側）→ 借方 = 原価 + 販管費 + その他費用純額 + 税引前損失は貸方へ
  - 三菱商事: other_net = +677,473百万（収益側）→ 貸方 = 収益 + その他収益純額
- 比率は `revenue` を100とした売上収益比（既存PLと同じ流儀）。
- 返却フィールド（GraphQL）: `revenue, costOfSales, sellingGeneralExpense, otherIncomeExpenseNet,
  profitLossBeforeTax` の amount/ratio。符号の解釈（どちらの棒に積むか）はフロントの
  チャートコンポーネントが行う（04参照）。

**CF**: 構造は日本基準と同一のため、既存 `cash_flow` フィールド
（startingCash / operating / investing / financing / endingCash）にそのまま詰める。**新型は作らない。**

## 4. GraphQL スキーマ

`CompanyFinancialStatementType` に追加（既存フィールドは変更しない = 破壊的変更なし）:

```ruby
field :accounting_standard, String   # "japan_gaap" | "ifrs"
field :balance_sheet, BalanceSheetType          # 既存。IFRS行では null
field :profit_loss, ProfitLossType              # 既存。IFRS行では null
field :ifrs_balance_sheet, IfrsBalanceSheetType # 新規。japan_gaap行では null
field :ifrs_profit_loss, IfrsProfitLossType     # 新規。japan_gaap行では null
field :cash_flow, CashFlowType                  # 既存を共用
```

新規型（`app/graphql/types/financial_statement/` に追加。既存の amount/ratio 2層構造に合わせる）:

```
IfrsBalanceSheetType    { amount: IfrsBalanceSheetAmountType, ratio: IfrsBalanceSheetRatioType }
  amount/ratio fields: currentAsset, nonCurrentAsset, currentLiability, nonCurrentLiability, equity
IfrsProfitLossType      { amount: IfrsProfitLossAmountType, ratio: IfrsProfitLossRatioType }
  amount/ratio fields: revenue, costOfSales, sellingGeneralExpense, otherIncomeExpenseNet, profitLossBeforeTax
```

- 会計基準別の型を union にせず「基準別 nullable フィールド + accountingStandard」で表現する。
  フロントの分岐が単純になり、既存クエリを壊さない。
- `QueryType` は変更不要（FetcherServiceの戻り値にキーが増えるだけ）。
