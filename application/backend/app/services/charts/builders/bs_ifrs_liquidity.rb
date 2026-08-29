class Charts::Builders::BsIfrsLiquidity < Charts::Builders::StackBase
  # 流動性配列: 流動/非流動の区分が存在しないため「現金及び現金同等物 + その他資産（導出）」の2段で表現
  def build
    assets = val("bs.assets")
    cash = val("bs.cash_and_equivalents")
    other_assets = assets && cash ? assets - cash : nil
    two_sided_chart(
      debit_specs: [
        [ "cash",        "現金及び現金同等物", cash,         "asset1" ],
        [ "otherAssets", "その他資産",         other_assets, "asset2" ]
      ],
      credit_specs: [
        [ "liabilities", "負債", "bs.liabilities", "liability1" ]
      ],
      equity: val("bs.equity"), equity_label: "資本", base: assets,
      unrenderable_note: no_data_note("財政状態計算書"))
  end
end
