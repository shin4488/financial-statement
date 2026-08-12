class Charts::Builders::BsIfrsClassified < Charts::Builders::StackBase
  def build
    two_sided_chart(
      debit_specs: [
        [ "currentAssets",    "流動資産",   "bs.current_assets",     "asset1" ],
        [ "nonCurrentAssets", "非流動資産", "bs.non_current_assets", "asset2" ]
      ],
      credit_specs: [
        [ "currentLiabilities",    "流動負債",   "bs.current_liabilities",     "liability1" ],
        [ "nonCurrentLiabilities", "非流動負債", "bs.non_current_liabilities", "liability2" ]
      ],
      equity: val("bs.equity"), equity_label: "資本", base: val("bs.assets"),
      unrenderable_note: "財政状態計算書: データがない、または表示対応していないデータです。")
  end
end
