class Charts::Builders::BsJgaapGeneral < Charts::Builders::StackBase
  def build
    # 比率の分母をbs.assetsでなく「表示する4科目の合計」にする理由:
    # jppfs_cor:Assetsには繰延資産など表示しない科目も含まれ得るため、
    # bs.assetsを分母にすると表示セグメントの比率合計が100%に届かない企業が出る。
    # 表示するものの合計を分母にすれば定義上100%で完結する
    base = %w[bs.current_assets bs.tangible_fixed_assets
              bs.intangible_fixed_assets bs.investments_and_other_assets].sum { |c| val(c).to_i }
    two_sided_chart(
      debit_specs: [
        [ "currentAssets",  "流動資産",       "bs.current_assets",               "asset1" ],
        [ "tangible",       "有形固定資産",   "bs.tangible_fixed_assets",        "asset2" ],
        [ "intangible",     "無形固定資産",   "bs.intangible_fixed_assets",      "asset3" ],
        [ "investments",    "投資その他資産", "bs.investments_and_other_assets", "asset4" ]
      ],
      credit_specs: [
        [ "currentLiabilities", "流動負債", "bs.current_liabilities",     "liability1" ],
        [ "fixedLiabilities",   "固定負債", "bs.non_current_liabilities", "liability2" ]
      ],
      equity: val("bs.equity"), equity_label: "純資産", base: base,
      unrenderable_note: "貸借対照表: データがない、または表示対応していないデータです。")
  end
end
