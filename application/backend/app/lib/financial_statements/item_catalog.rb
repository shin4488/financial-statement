module FinancialStatements
  # 保存する科目の一覧。科目ごとに、期間・期首の科目・意味を1行で書く。
  #
  # 科目コードの命名規則: "<財務諸表>.<科目のスネークケース英名>"
  #   bs. = 貸借対照表（財政状態計算書） / pl. = 損益計算書 / cf. = キャッシュ・フロー計算書
  #
  # 行の書き方:
  #   instant  … 当期末の残高（時点）
  #   duration … 当期の増減（期間）
  #   opening  … of: の科目の、同じ有報・同じ連結区分の前期末の残高。期首の科目として保存し、別の有報から補わない
  #
  # 値が取れない科目は行を作らない（= どの科目が欠けてもエラーではない）。
  #
  # 1科目ずつ説明（意味と、形式ごとの違い）を書けることがこの一覧の価値なので、科目をまとめて列挙する書き方にしない。
  #
  # ifrs_summary（経営指標サマリのみで構成する形式）は各セクションの形式の列挙に含めず、PL・CFに加え、指標に必要な総資産・自己資本（期首/期末）・親会社帰属利益を保存する。
  # usgaap_summary（米国基準。経営指標サマリのみで構成する形式）も列挙に含めず、CFと、指標に必要な総資産・自己資本（期首/期末）・親会社帰属利益・売上だけを保存する
  module ItemCatalog
    # period は :instant（時点）か :duration（期間）。opening_of は、期首の科目のときに前期末の残高を使う科目
    Item = Data.define(:code, :period, :description, :opening_of) do
      def opening? = !opening_of.nil?
    end

    def self.instant(code, description) = Item.new(code:, period: :instant, description:, opening_of: nil)
    def self.duration(code, description) = Item.new(code:, period: :duration, description:, opening_of: nil)
    def self.opening(code, description, of:) = Item.new(code:, period: :instant, description:, opening_of: of)
    private_class_method :instant, :duration, :opening

    ITEMS = [
      # ---- 全形式共通（jgaap_general / jgaap_bank / jgaap_insurance / ifrs_classified / ifrs_liquidity すべてが保存する）----
      instant("bs.assets",                               "資産合計"),
      opening("bs.assets_begin",                         "同じ有報の前期末総資産（期首）", of: "bs.assets"),
      instant("bs.equity_attributable_to_owners",        "自己資本（日本基準）/ 親会社所有者帰属持分（IFRS）"),
      opening("bs.equity_attributable_to_owners_begin",  "同じ有報の前期末自己資本（期首）", of: "bs.equity_attributable_to_owners"),
      instant("bs.liabilities",                          "負債合計"),
      instant("bs.equity",                               "資本合計（日本基準では純資産合計）"),
      instant("bs.cash_and_equivalents",                 "現金及び現金同等物（銀行は「現金預け金」、保険は「現金及び預貯金」）"),
      # ---- IFRSのみ（ifrs_classified / ifrs_liquidity が保存する）----
      instant("bs.non_controlling_interests",            "非支配持分"),
      # ---- 流動/非流動の分類がある形式のみ（jgaap_general / ifrs_classified が保存する）----
      instant("bs.current_assets",                       "流動資産"),
      instant("bs.non_current_assets",                   "非流動資産（日本基準では固定資産）"),
      instant("bs.current_liabilities",                  "流動負債"),
      instant("bs.non_current_liabilities",              "非流動負債（日本基準では固定負債）"),
      # ---- 日本基準・一般のみ（jgaap_general が保存する。固定資産の3分類）----
      instant("bs.tangible_fixed_assets",                "有形固定資産"),
      instant("bs.intangible_fixed_assets",              "無形固定資産"),
      instant("bs.investments_and_other_assets",         "投資その他の資産"),
      instant("bs.deferred_assets",                      "繰延資産（創立費・開業費・株式交付費・社債発行費など）"),
      # ---- IFRS・流動/非流動分類のみ（ifrs_classified が保存する。非流動資産の代表内訳）----
      instant("bs.property_plant_and_equipment",         "有形固定資産"),
      instant("bs.goodwill_and_intangibles",             "のれん及び無形資産（別掲企業は対応表で合算する）"),
      # ---- 銀行・保険（jgaap_bank / jgaap_insurance が保存する）----
      instant("bs.loans",                                "貸出金（保険では貸付金）"),
      instant("bs.securities",                           "有価証券"),
      # ---- 銀行のみ（jgaap_bank が保存する）----
      instant("bs.deposits",                             "預金"),
      # ---- 保険のみ（jgaap_insurance が保存する）----
      instant("bs.policy_reserves",                      "保険契約準備金"),

      duration("pl.gas_miscellaneous_expenses",          "ガス雑営業費用"),
      duration("pl.gas_incidental_expenses",             "ガス附帯事業費用"),
      duration("pl.other_operating_income",              "その他収益（IFRS）"),
      duration("pl.other_operating_expenses",            "その他費用（IFRS）"),
      duration("pl.other_income_expenses_net",           "その他損益の純額（IFRS）"),
      duration("pl.research_and_development",            "研究開発費（IFRS。他の費用と重複する場合がある）"),
      duration("pl.general_and_administrative_expenses", "一般管理費（IFRS。販管費とは別の行で開示する会社がある。売上0のグラフだけで使う）"),
      duration("pl.finance_income",                      "金融収益（IFRS）"),
      duration("pl.finance_costs",                       "金融費用（IFRS）"),
      duration("pl.equity_method_profit",                "持分法による投資損益（IFRS。符号を保持する）"),
      # ---- 全形式共通 ----
      duration("pl.profit_before_tax",                   "税引前利益（日本基準では税引前当期純利益）"),
      duration("pl.income_tax",                          "法人税等 / 法人所得税費用"),
      duration("pl.profit",                              "当期純利益 / 当期利益"),
      duration("pl.profit_attributable_to_owners",       "親会社株主（所有者）に帰属する当期純利益"),
      # ---- 銀行・保険以外（jgaap_general / ifrs_classified / ifrs_liquidity が保存する）----
      duration("pl.revenue",                             "売上高・営業収益（日本基準）/ 売上収益・収益（IFRS）"),
      duration("pl.summary_revenue",                     "経営指標の要約（主要な経営指標等の推移）の売上。売上の照合に使う（ifrs_summary も保存する）"),
      duration("pl.cost_of_sales",                       "売上原価（IFRSでは開示任意 → 無い企業がある）"),
      duration("pl.sga",                                 "販売費及び一般管理費（IFRSでは開示任意）"),
      # ---- 日本基準・一般のみ（jgaap_general が保存する）----
      duration("pl.financial_expenses",                  "金融費用（証券・商品先物。営業収益−金融費用=純営業収益）"),
      duration("pl.non_sales_operating_revenue",         "営業収入（営業収益のうち売上高以外）。売上の照合に使う"),
      duration("pl.non_operating_income",                "営業外収益"),
      duration("pl.non_operating_expenses",              "営業外費用"),
      # ---- 日本基準・一般 + IFRS（jgaap_general は必ず、ifrs_classified / ifrs_liquidity は任意開示があれば保存する）----
      duration("pl.gross_profit",                        "売上総利益（営業総利益を含む）"),
      duration("pl.operating_profit",                    "営業利益"),
      # ---- 日本基準のみ・特別損益（jgaap_general / jgaap_bank / jgaap_insurance が保存する）----
      duration("pl.extraordinary_income",                "特別利益"),
      duration("pl.extraordinary_loss",                  "特別損失"),
      # ---- 日本基準のみ・経常利益（jgaap_general / jgaap_bank / jgaap_insurance が保存する。IFRSに概念が存在しない）----
      duration("pl.ordinary_profit",                     "経常利益"),
      # ---- 銀行・保険のみ（jgaap_bank / jgaap_insurance が保存する）----
      duration("pl.ordinary_revenue",                    "経常収益（銀行・保険のトップライン。pl.revenueは保存しない）"),
      duration("pl.ordinary_expenses",                   "経常費用"),
      # ---- 営業費用一括型（ifrs_* と、日本基準の電気・鉄道・特定金融・商品先物など該当タグがあれば保存する）----
      duration("pl.operating_expenses",                  "営業費用（原価/販管費に分解されない一括計上。売上原価を別掲する商品先物ではその控除後）"),

      # ---- 全形式共通（CFは基準・業種によらず構造が同一）----
      duration("cf.new_consolidation",                   "新規連結に伴う現金残高の増加"),
      duration("cf.consolidation_change",                "連結範囲変更による現金残高の増減"),
      duration("cf.merger",                              "合併に伴う現金及び現金同等物の増減"),
      duration("cf.exchange_effect",                     "現金及び現金同等物に係る換算差額"),
      opening("cf.cash_begin",                           "現金及び現金同等物の期首残高（前期末 Prior1YearInstant）", of: "cf.cash_end"),
      duration("cf.operating",                           "営業活動によるキャッシュ・フロー"),
      duration("cf.investing",                           "投資活動によるキャッシュ・フロー"),
      duration("cf.financing",                           "財務活動によるキャッシュ・フロー"),
      instant("cf.cash_end",                             "現金及び現金同等物の期末残高")
    ].freeze

    ALL = ITEMS.map(&:code).freeze

    def self.opening_codes = ITEMS.select(&:opening?).map(&:code)
  end
end
