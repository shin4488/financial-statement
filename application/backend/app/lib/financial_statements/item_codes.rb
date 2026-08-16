module FinancialStatements
  module ItemCodes
    # 科目コードの命名規則: "<財務諸表>.<科目のスネークケース英名>"
    #   bs. = 貸借対照表（財政状態計算書） / pl. = 損益計算書 / cf. = キャッシュ・フロー計算書
    #
    # 値が取れない科目は行を作らない（= どの科目が欠けてもエラーではない）。
    #
    # コメントを1コードずつ書けるよう %w[] ではなく通常の配列リテラルで定義する
    # （%w[] 内にはコメントを書けないため。この可読性はレジストリの本質的な価値なので崩さないこと）

    BS = [
      # ---- 全形式共通（jgaap_general / jgaap_bank / jgaap_insurance / ifrs_classified / ifrs_liquidity すべてが保存する）----
      "bs.assets",                        # 資産合計
      "bs.liabilities",                   # 負債合計
      "bs.equity",                        # 資本合計（日本基準では純資産合計）
      "bs.cash_and_equivalents",          # 現金及び現金同等物（銀行は「現金預け金」、保険は「現金及び預貯金」）
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
      # ---- 銀行・保険（jgaap_bank / jgaap_insurance が保存する）----
      "bs.loans",                         # 貸出金（保険では貸付金）
      "bs.securities",                    # 有価証券
      # ---- 銀行のみ（jgaap_bank が保存する）----
      "bs.deposits",                      # 預金
      # ---- 保険のみ（jgaap_insurance が保存する）----
      "bs.policy_reserves"               # 保険契約準備金
    ].freeze

    PL = [
      # ---- 全形式共通 ----
      "pl.profit_before_tax",             # 税引前利益（日本基準では税引前当期純利益）
      "pl.income_tax",                    # 法人税等 / 法人所得税費用
      "pl.profit",                        # 当期純利益 / 当期利益
      "pl.profit_attributable_to_owners", # 親会社株主（所有者）に帰属する当期純利益
      # ---- 銀行・保険以外（jgaap_general / ifrs_classified / ifrs_liquidity が保存する）----
      "pl.revenue",                       # 売上高・営業収益（日本基準）/ 売上収益・収益（IFRS）
      "pl.cost_of_sales",                 # 売上原価（IFRSでは開示任意 → 無い企業がある）
      "pl.sga",                           # 販売費及び一般管理費（IFRSでは開示任意）
      # ---- 日本基準・一般のみ（jgaap_general が保存する）----
      "pl.financial_expenses",            # 金融費用（証券・商品先物。営業収益−金融費用=純営業収益）
      "pl.gross_profit",                  # 売上総利益（営業総利益を含む）
      "pl.operating_profit",              # 営業利益（IFRSでも任意開示があれば ifrs_* も保存する）
      "pl.non_operating_income",          # 営業外収益
      "pl.non_operating_expenses",        # 営業外費用
      # ---- 日本基準のみ・特別損益（jgaap_general / jgaap_bank / jgaap_insurance が保存する）----
      "pl.extraordinary_income",          # 特別利益
      "pl.extraordinary_loss",            # 特別損失
      # ---- 日本基準のみ・経常利益（jgaap_general / jgaap_bank / jgaap_insurance が保存する。IFRSに概念が存在しない）----
      "pl.ordinary_profit",               # 経常利益
      # ---- 銀行・保険のみ（jgaap_bank / jgaap_insurance が保存する）----
      "pl.ordinary_revenue",              # 経常収益（銀行・保険のトップライン。pl.revenueは保存しない）
      "pl.ordinary_expenses",             # 経常費用
      # ---- 営業費用一括型（ifrs_* と、日本基準の電気・鉄道・特定金融など該当タグがあれば保存する）----
      "pl.operating_expenses"            # 営業費用（原価/販管費に分解されない一括計上）
    ].freeze

    CF = [
      # ---- 全形式共通（CFは基準・業種によらず構造が同一）----
      "cf.cash_begin",                    # 現金及び現金同等物の期首残高（前期末 Prior1YearInstant）
      "cf.operating",                     # 営業活動によるキャッシュ・フロー
      "cf.investing",                     # 投資活動によるキャッシュ・フロー
      "cf.financing",                     # 財務活動によるキャッシュ・フロー
      "cf.cash_end"                      # 現金及び現金同等物の期末残高
    ].freeze

    ALL = (BS + PL + CF).freeze
  end
end
