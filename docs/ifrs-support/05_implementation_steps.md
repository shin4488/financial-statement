# 実装手順・テスト・バックフィル

## 実装順序

バックエンド→フロントの順。各ステップは独立してマージ可能な粒度にする。

1. **DB**: `ifrs_financial_statements` マイグレーション + `IfrsFinancialStatement` モデル +
   `SecurityReport has_one :ifrs_financial_statement`（[02](02_database_design.md)）
2. **Reader**: `SingleSecurityReportsReader` を `readers/japan_gaap_statement_reader.rb` へ移設（挙動変更なし）、
   `readers/ifrs_statement_reader.rb` 新規、`ReaderRepository` の委譲追加（[03 §1](03_backend_design.md)）
3. **Subscriber**: `create_ifrs_financial_statement` 追加（[03 §2](03_backend_design.md)）
4. **Fetcher/GraphQL**: モデルのクエリ変更、Presenter分割、GraphQL型追加（[03 §3-4](03_backend_design.md)）
5. **フロント**: クエリ・state拡張 → codegen → IFRSチャート2コンポーネント → 一覧ページ分岐（[04](04_frontend_design.md)）
6. **バックフィル**: 過去のIFRS有報の再取込（下記）

## 動作確認・テスト観点

### Readerの確認（実データ）

検証済みのdocIDを使うと期待値の照合がしやすい（数値は [01_xbrl_research.md](01_xbrl_research.md) 執筆時に取得済み）:

- 武田薬品工業: `S100YB5L`（営業利益あり・売上総利益なし・税引前損失・その他損益が費用側）
- 三菱商事: `S100YB25`（売上総利益あり・営業利益なし・その他損益が収益側・のれん無形が合算タグ）

`rails c` での確認例:

```ruby
SecurityReport::SubscriberService.subscribe_by_target_document_ids(target_document_ids: ["S100YB5L", "S100YB25"])
IfrsFinancialStatement.joins(security_report: :company).pluck("companies.company_japanese_name", :revenue, :profit_loss_before_tax, :asset, :equity)
```

期待値の例（2026/3期、単位:円）:

| | 武田薬品 | 三菱商事 |
|---|---|---|
| revenue | 4,505,720,000,000 | 18,915,995,000,000 |
| profit_loss_before_tax | -142,355,000,000 | 1,096,094,000,000 |
| asset | 15,511,506,000,000 | 24,151,695,000,000 |
| equity | 7,430,649,000,000 | 10,250,574,000,000 |
| operating_profit_loss | 6,217,000,000 | NULL |
| gross_profit | NULL | 1,655,074,000,000 |
| goodwill_and_intangible_asset | 9,228,358,000,000（のれん5,809,010+無形3,419,348の合算） | 913,374,000,000 |
| operating_activity_cash_flow | 1,041,431,000,000 | 1,490,041,000,000 |
| start_cash_flow_balance | 385,113,000,000 | 1,536,624,000,000 |

### 回帰確認（日本基準）

- 日本基準企業のdocIDを1件取り込み、`security_reports` の保存値が変更前と一致すること
  （Reader移設が純粋なリファクタであることの確認）。
- 既存GraphQLクエリ（`accountingStandard` 等を要求しない従来形）がそのまま動くこと。

### Presenter/チャートのエッジケース

- IFRSで `equity < 0`（債務超過）→ 3本目バー表示
- `profit_loss_before_tax < 0` → 貸方に税引前損失（武田で確認可能）
- `otherIncomeExpenseNet` 正負両方（三菱商事=正 / 武田=負）
- `cost_of_sales` や `selling_general_and_administrative_expense` が NULL の企業
  （サービス業のIFRS企業等で発生し得る）→ 段をスキップして描画が破綻しないこと
- `ifrs_financial_statements` 行がないIFRS有報が一覧に出ないこと
- CF符号フィルタがIFRS行にも効くこと

## 過去データのバックフィル

既存DBのIFRS有報は連結値が入っていない。実装完了後に過去分を再取込する:

```ruby
# 対象期間を区切って実行（EDINET APIのレート制限のため同期処理・日単位）
SecurityReport::SubscriberService.subscribe(from_date: Date.new(2024, 1, 1), to_date: Date.new(2024, 12, 31))
```

- `SecurityReport` / `Company` / `IfrsFinancialStatement` とも upsert のため再実行は冪等。
- EDINET APIの書類一覧・取得APIは過去10年分が対象。必要な年数分を日次ループで回す
  （`subscribe` が日単位でループする実装のため、期間を渡すだけでよい）。
- 全期間の再取込は時間がかかる（1日分ずつ同期取得）。IFRS有報だけに絞る最適化をするなら、
  `documents.json` のレスポンスだけでは会計基準が分からないため、いったん全件ダウンロードして
  Readerで判定する現行フローのままが単純（最適化はスコープ外）。

## 将来拡張の余地（実装対象外・メモ）

- 非流動資産の内訳（`property_plant_and_equipment` / `goodwill_and_intangible_asset`）は
  DBに保存するためツールチップや詳細表示に利用可能。
- 金融収益/費用・持分法損益を個別カラム化すれば「その他損益（純額）」の内訳表示が可能
  （タグは01参照: `FinanceIncomeIFRS` / `FinanceCostsIFRS` / `ShareOfProfitLossOfInvestmentsAccountedForUsingEquityMethodIFRS`）。
- US GAAP対応は本表の詳細タグがEDINETタクソノミに存在しないため、
  `jpcrp_cor` の経営指標サマリ（5年分）ベースの簡易表示という別アプローチになる。
