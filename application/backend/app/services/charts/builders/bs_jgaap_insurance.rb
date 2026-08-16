class Charts::Builders::BsJgaapInsurance < Charts::Builders::StackBase
  # 保険: 資産の大半を占める有価証券と、貸付金・現金及び預貯金 + 負債の大半を占める保険契約準備金を
  # 内訳表示する。「その他」を残差で導出する意図は銀行と同じ（内訳科目が多数で全列挙は保守コストが高い）。
  # BsJgaapBankと構造が似るが共有・継承しない（形式ごとに独立して保守するため。Extractorと同じ方針）
  def build
    # 保険契約準備金が取れない場合は描画しない。負債全額を「その他負債」として描くと
    # 「保険契約準備金0%の保険会社」という誤ったグラフになるため（形式判定ミスか取込不良の可能性が高い）。
    # 資産側の内訳は欠けても残差の「その他資産」に吸収されるだけなので許容する
    policy_reserves = val("bs.policy_reserves")
    return Charts::StackChart.unrenderable("貸借対照表: データがない、または表示対応していないデータです。") if policy_reserves.nil?

    assets = val("bs.assets")
    known_assets = %w[bs.cash_and_equivalents bs.securities bs.loans].sum { |c| val(c).to_i }
    other_assets = assets ? assets - known_assets : nil
    liabilities = val("bs.liabilities")
    other_liabilities = liabilities ? liabilities - policy_reserves : nil
    two_sided_chart(
      debit_specs: [
        [ "cash",        "現金及び預貯金", "bs.cash_and_equivalents", "asset1" ],
        [ "securities",  "有価証券",       "bs.securities",           "asset3" ],
        [ "loans",       "貸付金",         "bs.loans",                "asset2" ],
        [ "otherAssets", "その他資産",     other_assets,              "asset4" ]
      ],
      credit_specs: [
        [ "policyReserves",   "保険契約準備金", "bs.policy_reserves", "liability1" ],
        [ "otherLiabilities", "その他負債",     other_liabilities,    "liability2" ]
      ],
      equity: val("bs.equity"), equity_label: "純資産", base: assets,
      unrenderable_note: "貸借対照表: データがない、または表示対応していないデータです。")
  end
end
