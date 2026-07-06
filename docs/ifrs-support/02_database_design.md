# テーブル設計

## 方針

- 既存 `security_reports` は「有報ヘッダ（会計年度・会計基準・提出日等）+ 日本基準の科目」として**変更しない**。
- IFRS連結財務諸表の科目は新テーブル `ifrs_financial_statements` に持つ（1有報 : 0..1行）。
- 会計基準ごとにテーブルを分けることで、科目体系の違い（経常利益がない、資産3分類がない等）を
  無理にマッピングせず、将来の基準追加（例: 金融業フォーマット）も同じパターンで拡張できる。

## 新テーブル: `ifrs_financial_statements`

- IFRSは連結のみ対象のため `consolidated_` プレフィクスは付けない（テーブル名が基準を、行の存在が連結を表す）。
- 金額は既存に合わせ `bigint`（円）。
- **開示が任意の科目があるため、値が取れなかった科目は 0 ではなく NULL で保存する**
  （既存の `.to_i` による0埋めはIFRSでは「非開示」と「ゼロ」の区別を壊すため踏襲しない）。

```ruby
create_table :ifrs_financial_statements, comment: "IFRS連結財務諸表" do |t|
  t.bigint :security_report_id, null: false, comment: "有価証券報告書id"

  # BS（連結財政状態計算書）
  t.bigint :current_asset,                comment: "流動資産"
  t.bigint :non_current_asset,            comment: "非流動資産"
  t.bigint :asset,                        comment: "資産合計"
  t.bigint :property_plant_and_equipment, comment: "有形固定資産"
  t.bigint :goodwill_and_intangible_asset, comment: "のれん及び無形資産"
  t.bigint :current_liability,            comment: "流動負債"
  t.bigint :non_current_liability,        comment: "非流動負債"
  t.bigint :liability,                    comment: "負債合計"
  t.bigint :equity_attributable_to_owners_of_parent, comment: "親会社の所有者に帰属する持分"
  t.bigint :non_controlling_interest,     comment: "非支配持分"
  t.bigint :equity,                       comment: "資本合計"

  # PL（連結損益計算書）
  t.bigint :revenue,                      comment: "売上収益"
  t.bigint :cost_of_sales,                comment: "売上原価"
  t.bigint :gross_profit,                 comment: "売上総利益"
  t.bigint :selling_general_and_administrative_expense, comment: "販売費及び一般管理費"
  t.bigint :operating_profit_loss,        comment: "営業利益"
  t.bigint :profit_loss_before_tax,       comment: "税引前利益"
  t.bigint :income_tax_expense,           comment: "法人所得税費用"
  t.bigint :profit_loss,                  comment: "当期利益"
  t.bigint :profit_loss_attributable_to_owners_of_parent, comment: "親会社の所有者に帰属する当期利益"

  # CF（連結キャッシュ・フロー計算書）
  t.bigint :start_cash_flow_balance,      comment: "現金及び現金同等物の期首残高"
  t.bigint :operating_activity_cash_flow, comment: "営業活動によるキャッシュフロー"
  t.bigint :investing_activity_cash_flow, comment: "投資活動によるキャッシュフロー"
  t.bigint :financing_activity_cash_flow, comment: "財務活動によるキャッシュフロー"
  t.bigint :end_cash_flow_balance,        comment: "現金及び現金同等物の期末残高"

  t.timestamps
  t.index [:security_report_id], unique: true
end
add_foreign_key :ifrs_financial_statements, :security_reports
```

## カラム選定の考え方

- **グラフ描画に必要な合計科目 + わずかな内訳** に絞る（04のグラフ設計から逆算）。
  内訳明細（棚卸資産、社債及び借入金等）は企業ごとに構成が異なり網羅コストが高いため持たない。
- `property_plant_and_equipment` / `goodwill_and_intangible_asset` は非流動資産の代表的内訳として保持
  （ツールチップ等の将来拡張用。グラフの積み上げ本体には使わない）。
  武田型（`GoodwillIFRS` と `IntangibleAssetsIFRS` が別掲）は **Reader側で合算**して1カラムに保存する。
- `gross_profit` / `operating_profit_loss` は開示がある企業のみ値が入る（NULL許容が本質的に必要な例）。
- CFカラム名は `investing_activity_cash_flow`（IFRSタグの綴りに合わせる。既存日本基準カラムは
  `investment_activity_cash_flow` だが、これはテーブルが分かれているので混在しない）。

## upsert（修正取込対応）

既存 `security_reports` と同様に修正有報の再取込を可能とするため、
`security_report_id` のユニークキーで `IfrsFinancialStatement.upsert(..., unique_by: :security_report_id)` する。

## 既存テーブルとの関係

- `security_reports.accounting_standard`（enum: japan_gaap 0 / us_gaap 1 / ifrs 2）は既存のまま判別に使う。
- IFRS有報の行では、既存の `consolidated_*` カラムは今後も**すべてNULL（保存しない）**とし、
  `non_consolidated_*` カラムには従来どおり日本基準の単体値が入る。
- モデル関連:
  ```ruby
  class SecurityReport < ApplicationRecord
    has_one :ifrs_financial_statement
  end
  class IfrsFinancialStatement < ApplicationRecord
    belongs_to :security_report
  end
  ```

## 既存データについて

DBに既に取り込まれているIFRS有報（`accounting_standard: ifrs`）は連結カラムが0のまま存在し得る。
新テーブルへのデータ投入はEDINETからの再取込（バックフィル）で行う。手順は [05_implementation_steps.md](05_implementation_steps.md) 参照。
