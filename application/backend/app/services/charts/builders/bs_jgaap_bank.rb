class Charts::Builders::BsJgaapBank < Charts::Builders::StackBase
  # 銀行: 分析の定番である貸出金・有価証券・現金預け金 + 預金を内訳表示する。
  # 「その他」を残差で導出する意図: 銀行の内訳科目は多数あり全列挙は保守コストが高い。
  # 分析上意味の大きい科目だけ実タグで取り、残りは合計からの差分で吸収する
  def build
    # 預金が取れない場合は描画しない。負債全額を「その他負債」として描くと
    # 「預金0%の銀行」という誤ったグラフになるため（銀行で預金タグが無いのは
    # 形式判定ミスか取込不良の可能性が高い）。
    # 資産側の内訳（貸出金等）は欠けても残差の「その他資産」に吸収されるだけなので許容する
    deposits = val("bs.deposits")
    return Charts::StackChart.unrenderable("貸借対照表: データがない、または表示対応していないデータです。") if deposits.nil?

    assets = val("bs.assets")
    known_assets = %w[bs.cash_and_equivalents bs.loans bs.securities].sum { |c| val(c).to_i }
    other_assets = assets ? assets - known_assets : nil
    liabilities = val("bs.liabilities")
    other_liabilities = liabilities ? liabilities - deposits : nil
    two_sided_chart(
      debit_specs: [
        [ "cash",        "現金預け金", "bs.cash_and_equivalents", "asset1" ],
        [ "loans",       "貸出金",     "bs.loans",                "asset2" ],
        [ "securities",  "有価証券",   "bs.securities",           "asset3" ],
        [ "otherAssets", "その他資産", other_assets,              "asset4" ]
      ],
      credit_specs: [
        [ "deposits",         "預金",       "bs.deposits",     "liability1" ],
        [ "otherLiabilities", "その他負債", other_liabilities, "liability2" ]
      ],
      equity: val("bs.equity"), equity_label: "純資産", base: assets,
      unrenderable_note: "貸借対照表: データがない、または表示対応していないデータです。")
  end
end
