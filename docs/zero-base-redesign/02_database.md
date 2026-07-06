# データベース設計

## ER図

```
companies 1 ─── * reports 1 ─── * financial_statements 1 ─── * financial_statement_items
```

- `reports` = 有価証券報告書1通
- `financial_statements` = その中の財務諸表1セット（連結 or 単体）。**会計基準・表示形式はこのレベルの属性**
  （IFRS企業でも単体は日本基準、という実態を正確にモデリングする）
- `financial_statement_items` = 正規化済み科目の縦持ち

## DDL（マイグレーション）

```ruby
class CreateCoreTables < ActiveRecord::Migration[7.0]
  def change
    create_table :companies, comment: "企業" do |t|
      t.string :edinet_code, limit: 6, null: false, comment: "EDINETコード"
      t.string :stock_code, limit: 5, comment: "証券コード（5桁）"
      t.string :name_ja, comment: "企業名（日本語）"
      t.string :name_en, comment: "企業名（英語）"
      t.timestamps
      t.index :edinet_code, unique: true
      t.index :stock_code
    end

    create_table :reports, comment: "有価証券報告書" do |t|
      t.references :company, null: false, foreign_key: true, comment: "企業id"
      t.string :edinet_document_id, limit: 8, null: false, comment: "EDINET書類管理番号"
      t.date :fiscal_year_start_date, null: false, comment: "会計年度開始日"
      t.date :fiscal_year_end_date, null: false, comment: "会計年度終了日"
      t.date :filing_date, comment: "提出日"
      t.integer :accounting_standard, null: false, comment: "会計基準(DEI) 0:japan_gaap 1:us_gaap 2:ifrs"
      t.boolean :has_consolidated_statement, null: false, default: false, comment: "連結財務諸表あり"
      t.string :consolidated_industry_code, comment: "連結業種コード(DEI)"
      t.string :non_consolidated_industry_code, comment: "単体業種コード(DEI)"
      t.timestamps
      t.index [:company_id, :fiscal_year_start_date, :fiscal_year_end_date],
              unique: true, name: "idx_reports_company_fiscal_year"
      t.index :filing_date
    end

    create_table :financial_statements, comment: "財務諸表（連結/単体 × 1有報）" do |t|
      t.references :report, null: false, foreign_key: true, comment: "有報id"
      t.integer :consolidation_type, null: false, comment: "0:consolidated 1:non_consolidated"
      t.integer :accounting_standard, null: false, comment: "この財務諸表の会計基準（有報全体と異なり得る）"
      t.string :presentation_format, null: false, comment: "表示形式 jgaap_general/jgaap_bank/ifrs_classified/ifrs_liquidity/unsupported"
      t.boolean :is_primary, null: false, default: false, comment: "表示・検索の主対象（連結があれば連結）"
      t.timestamps
      t.index [:report_id, :consolidation_type], unique: true, name: "idx_fs_report_consolidation"
      t.index :is_primary
    end

    create_table :financial_statement_items, comment: "財務諸表科目（正規化・縦持ち）" do |t|
      t.references :financial_statement, null: false, foreign_key: true, index: false
      t.string :item_code, null: false, comment: "正規化科目コード（ItemCodesレジストリで管理）"
      t.bigint :amount, null: false, comment: "金額（円）。取得できなかった科目は行を作らない"
      t.timestamps
      t.index [:financial_statement_id, :item_code], unique: true, name: "idx_items_fs_code"
      t.index [:item_code, :amount], name: "idx_items_code_amount"  # CF符号フィルタ用
    end
  end
end
```

設計判断:

- **`amount` は NOT NULL**。「開示なし/取得不可」は行の不存在で表現する。0とNULLの区別問題を構造的に排除
- `presentation_format` は文字列（enumでなく）。形式追加時にマイグレーション不要にするため。
  値の正当性はモデルのバリデーション（`Ingestion::FormatRegistry` 参照）で担保
- `is_primary` は取込時に確定する非正規化フラグ（連結があれば連結、なければ単体）。
  一覧検索・CF符号フィルタのJOINを単純化するために持つ
- 比率・導出値（その他損益純額など）はDBに保存しない。表示層で計算する
  （保存すると形式追加のたびにバックフィルが必要になる）

## モデル

```ruby
class Company < ApplicationRecord
  has_many :reports
end

class Report < ApplicationRecord
  belongs_to :company
  has_many :financial_statements
  has_one :primary_financial_statement, -> { where(is_primary: true) },
          class_name: "FinancialStatement"
  enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }
end

class FinancialStatement < ApplicationRecord
  belongs_to :report
  has_many :items, class_name: "FinancialStatementItem"
  enum :consolidation_type, { consolidated: 0, non_consolidated: 1 }
  enum :accounting_standard, { japan_gaap: 0, us_gaap: 1, ifrs: 2 }, prefix: true
  validates :presentation_format, inclusion: { in: Ingestion::FormatRegistry::ALL }

  # {item_code => amount} のハッシュ。ChartBuilderへの入力形式
  # メモ化する理由: 1つの財務諸表からBS/PL/CFの3つのBuilderが呼ばれるため、
  # クエリを1回に抑える（eager_load済みならpluckはメモリ上で解決される）
  def items_hash
    @items_hash ||= items.pluck(:item_code, :amount).to_h
  end
end

class FinancialStatementItem < ApplicationRecord
  belongs_to :financial_statement
  validates :item_code, inclusion: { in: FinancialStatements::ItemCodes::ALL }
  validates :amount, presence: true
end
```

## 科目コードレジストリ

`app/models/concerns/` ではなく独立ファイル `app/lib/financial_statements/item_codes.rb`。
**科目の追加はこのファイルの1行追加**（DBマイグレーション不要）。

コメントを1コードずつ書けるよう `%w[]` ではなく通常の配列リテラルで定義する
（`%w[]` 内にはコメントを書けないため。この可読性はレジストリの本質的な価値なので崩さないこと）:

```ruby
module FinancialStatements
  module ItemCodes
    # 科目コードの命名規則: "<財務諸表>.<科目のスネークケース英名>"
    #   bs. = 貸借対照表（財政状態計算書） / pl. = 損益計算書 / cf. = キャッシュ・フロー計算書
    #
    # 「どの形式のExtractorがこのコードを保存するか」は、このファイル下部の対応表コメント
    # （ドキュメントでは 02_database.md の科目コード辞書）を必ず併記・同期すること。
    # 値が取れない科目は行を作らない（= どの科目が欠けてもエラーではない）。

    BS = [
      # ---- 全形式共通（jgaap_general / jgaap_bank / ifrs_classified / ifrs_liquidity すべてが保存する）----
      "bs.assets",                        # 資産合計
      "bs.liabilities",                   # 負債合計
      "bs.equity",                        # 資本合計（日本基準では純資産合計）
      "bs.cash_and_equivalents",          # 現金及び現金同等物（銀行のみ「現金預け金」）
      # ---- IFRSのみ（ifrs_classified / ifrs_liquidity が保存する）----
      "bs.equity_attributable_to_owners", # 親会社の所有者に帰属する持分
      "bs.non_controlling_interests",     # 非支配持分
      # ---- 流動/非流動の分類がある形式のみ（jgaap_general / ifrs_classified が保存する）----
      "bs.current_assets",                # 流動資産
      "bs.non_current_assets",            # 非流動資産（日本基準では固定資産）
      "bs.current_liabilities",           # 流動負債
      "bs.non_current_liabilities",       # 非流動負債（日本基準では固定負債）
      # ---- 日本基準・一般のみ（jgaap_general が保存する。固定資産の3分類）----
      "bs.tangible_fixed_assets",         # 有形固定資産
      "bs.intangible_fixed_assets",       # 無形固定資産
      "bs.investments_and_other_assets",  # 投資その他の資産
      # ---- IFRS・流動/非流動分類のみ（ifrs_classified が保存する。非流動資産の代表内訳）----
      "bs.property_plant_and_equipment",  # 有形固定資産
      "bs.goodwill_and_intangibles",      # のれん及び無形資産（別掲企業はExtractorが合算）
      # ---- 銀行のみ（jgaap_bank が保存する）----
      "bs.loans",                         # 貸出金
      "bs.securities",                    # 有価証券
      "bs.deposits",                      # 預金
    ].freeze

    PL = [
      # ---- 全形式共通 ----
      "pl.profit_before_tax",             # 税引前利益（日本基準では税引前当期純利益）
      "pl.income_tax",                    # 法人税等 / 法人所得税費用
      "pl.profit",                        # 当期純利益 / 当期利益
      "pl.profit_attributable_to_owners", # 親会社株主（所有者）に帰属する当期純利益
      # ---- 銀行以外（jgaap_general / ifrs_classified / ifrs_liquidity が保存する）----
      "pl.revenue",                       # 売上高（日本基準）/ 売上収益・収益（IFRS）
      "pl.cost_of_sales",                 # 売上原価（IFRSでは開示任意 → 無い企業がある）
      "pl.sga",                           # 販売費及び一般管理費（IFRSでは開示任意）
      # ---- 日本基準・一般のみ（jgaap_general が保存する）----
      "pl.gross_profit",                  # 売上総利益
      "pl.operating_profit",              # 営業利益（IFRSでも任意開示があれば ifrs_* も保存する）
      "pl.non_operating_income",          # 営業外収益
      "pl.non_operating_expenses",        # 営業外費用
      "pl.extraordinary_income",          # 特別利益
      "pl.extraordinary_loss",            # 特別損失
      # ---- 日本基準のみ・経常利益（jgaap_general / jgaap_bank が保存する。IFRSに概念が存在しない）----
      "pl.ordinary_profit",               # 経常利益
      # ---- 銀行のみ（jgaap_bank が保存する）----
      "pl.ordinary_revenue",              # 経常収益（銀行のトップライン。pl.revenueは保存しない）
      "pl.ordinary_expenses",             # 経常費用
      # ---- IFRSの営業費用一括型のみ（楽天・NTT型。ifrs_* が該当タグがあれば保存する）----
      "pl.operating_expenses",            # 営業費用（原価/販管費に分解されない一括計上）
    ].freeze

    CF = [
      # ---- 全形式共通（CFは基準・業種によらず構造が同一。01の実測で6社全社取得できた）----
      "cf.cash_begin",                    # 現金及び現金同等物の期首残高（前期末 Prior1YearInstant）
      "cf.operating",                     # 営業活動によるキャッシュ・フロー
      "cf.investing",                     # 投資活動によるキャッシュ・フロー
      "cf.financing",                     # 財務活動によるキャッシュ・フロー
      "cf.cash_end",                      # 現金及び現金同等物の期末残高
    ].freeze

    ALL = (BS + PL + CF).freeze
  end
end
```

### 科目コード辞書（生成元と消費先の完全な対応表）

「どのExtractorが保存し、どのChartBuilderが使うか」の全量。実装・レビュー時はこの表と
Extractorのマッピング定数（[03](03_backend_ingestion.md)）・Builderの参照コード（[04](04_backend_api.md)）の3点が一致していることを確認する。

**消費先が「−（保存のみ）」の科目について**: チャートで未使用でも保存する意図は、
(a) 取込の再実行コストが高い（EDINETから再ダウンロード）ため骨格科目は広めに取っておく、
(b) 将来の指標計算・ツールチップ・AIコメント生成（docs/improvements.md 3-3）の入力になる、の2点。

| コード | 日本語名 | 保存するExtractor | 消費するBuilder | 備考 |
|---|---|---|---|---|
| bs.assets | 資産合計 | 全4形式 | BsIfrsClassified(分母) / BsIfrsLiquidity / BsJgaapBank | JgaapGeneralのBuilderは使わない（分母は表示4科目の合計。04参照） |
| bs.liabilities | 負債合計 | 全4形式 | BsIfrsLiquidity / BsJgaapBank | 分類形式では流動+非流動を直接使うため未消費 |
| bs.equity | 資本（純資産）合計 | 全4形式 | 全BS Builder | 負値=債務超過の判定にも使う |
| bs.cash_and_equivalents | 現金及び現金同等物 | 全4形式 | BsIfrsLiquidity / BsJgaapBank | 銀行は「現金預け金」を格納 |
| bs.equity_attributable_to_owners | 親会社所有者帰属持分 | ifrs_classified / ifrs_liquidity | −（保存のみ） | |
| bs.non_controlling_interests | 非支配持分 | ifrs_classified / ifrs_liquidity | −（保存のみ） | |
| bs.current_assets | 流動資産 | jgaap_general / ifrs_classified | BsJgaapGeneral / BsIfrsClassified | |
| bs.non_current_assets | 非流動（固定）資産 | jgaap_general / ifrs_classified | BsIfrsClassified | jgaap_generalでは3分類表示のため未消費（保存はする） |
| bs.current_liabilities | 流動負債 | jgaap_general / ifrs_classified | BsJgaapGeneral / BsIfrsClassified | |
| bs.non_current_liabilities | 非流動（固定）負債 | jgaap_general / ifrs_classified | BsJgaapGeneral / BsIfrsClassified | |
| bs.tangible_fixed_assets | 有形固定資産 | jgaap_general | BsJgaapGeneral | |
| bs.intangible_fixed_assets | 無形固定資産 | jgaap_general | BsJgaapGeneral | |
| bs.investments_and_other_assets | 投資その他の資産 | jgaap_general | BsJgaapGeneral | |
| bs.property_plant_and_equipment | 有形固定資産(IFRS) | ifrs_classified | −（保存のみ） | 将来のツールチップ用 |
| bs.goodwill_and_intangibles | のれん及び無形資産 | ifrs_classified | −（保存のみ） | 別掲企業はExtractorが合算（武田の例: 07参照） |
| bs.loans | 貸出金 | jgaap_bank | BsJgaapBank | |
| bs.securities | 有価証券 | jgaap_bank | BsJgaapBank | |
| bs.deposits | 預金 | jgaap_bank | BsJgaapBank | |
| pl.profit_before_tax | 税引前利益 | 全4形式 | PlIfrs | jgaap系Builderは営業利益/経常利益を使うため未消費（保存はする） |
| pl.income_tax | 法人税等 | 全4形式 | −（保存のみ） | |
| pl.profit | 当期純利益 | 全4形式 | −（保存のみ） | |
| pl.profit_attributable_to_owners | 親会社帰属当期純利益 | 全4形式 | −（保存のみ） | |
| pl.revenue | 売上高/売上収益 | jgaap_general / ifrs_classified / ifrs_liquidity | PlJgaapGeneral / PlIfrs | 銀行は保存しない（pl.ordinary_revenueが銀行のトップライン） |
| pl.cost_of_sales | 売上原価 | jgaap_general / ifrs_* | PlJgaapGeneral / PlIfrs | IFRSは開示任意（武田○・楽天×） |
| pl.sga | 販売費及び一般管理費 | jgaap_general / ifrs_* | PlJgaapGeneral / PlIfrs | 同上 |
| pl.gross_profit | 売上総利益 | jgaap_general / ifrs_*（任意開示） | −（保存のみ） | 取込データの検算に有用 |
| pl.operating_profit | 営業利益 | jgaap_general / ifrs_*（任意開示） | PlJgaapGeneral | PlIfrsは使わない（開示が任意で企業間比較できないため骨格から除外） |
| pl.non_operating_income / expenses | 営業外収益/費用 | jgaap_general | −（保存のみ） | |
| pl.ordinary_profit | 経常利益 | jgaap_general / jgaap_bank | PlJgaapBank | |
| pl.ordinary_revenue / expenses | 経常収益/費用 | jgaap_bank | PlJgaapBank | |
| pl.extraordinary_income / loss | 特別利益/損失 | jgaap_general | −（保存のみ） | |
| pl.operating_expenses | 営業費用（一括） | ifrs_*（該当タグがある企業のみ） | PlIfrs | 楽天・NTT型 |
| cf.cash_begin / operating / investing / financing / cash_end | CF5点セット | 全4形式 | CashFlow（共通Builder） | 5点全部そろわないと表示不可（04参照） |

## 検索クエリの例（CF符号フィルタ）

縦持ちでも `is_primary` と `(item_code, amount)` 複合インデックスにより既存機能と同等の検索が可能:

```sql
SELECT reports.* FROM reports
JOIN financial_statements fs ON fs.report_id = reports.id AND fs.is_primary
WHERE EXISTS (
  SELECT 1 FROM financial_statement_items i
  WHERE i.financial_statement_id = fs.id
    AND i.item_code = 'cf.operating' AND i.amount > 0)
  AND EXISTS (
  SELECT 1 FROM financial_statement_items i
  WHERE i.financial_statement_id = fs.id
    AND i.item_code = 'cf.investing' AND i.amount < 0)
ORDER BY reports.filing_date DESC NULLS LAST, reports.fiscal_year_end_date DESC, reports.updated_at DESC
LIMIT 100 OFFSET 0;
```
