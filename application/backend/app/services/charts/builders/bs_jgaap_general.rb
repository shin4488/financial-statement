class Charts::Builders::BsJgaapGeneral < Charts::Builders::StackBase
  # 固定資産の内訳（財務諸表等規則の3分類）。一般事業会社はこの3つの合計が固定資産に一致する
  FIXED_ASSET_BREAKDOWN = [
    [ "tangible",    "有形固定資産",   "bs.tangible_fixed_assets",        "asset2" ],
    [ "intangible",  "無形固定資産",   "bs.intangible_fixed_assets",      "asset3" ],
    [ "investments", "投資その他資産", "bs.investments_and_other_assets", "asset4" ]
  ].freeze
  FIXED_ASSET_TOTAL = [ "fixedAssets", "固定資産", "bs.non_current_assets", "asset2" ].freeze

  def build
    debit_specs = [ [ "currentAssets", "流動資産", "bs.current_assets", "asset1" ], *fixed_asset_specs ]
    # 比率の分母をbs.assetsでなく「表示する科目の合計」にする理由:
    # jppfs_cor:Assetsには繰延資産など表示しない科目も含まれ得るため、
    # bs.assetsを分母にすると表示セグメントの比率合計が100%に届かない企業が出る。
    # 表示するものの合計を分母にすれば定義上100%で完結する
    base = debit_specs.sum { |_, _, code, _| val(code).to_i }
    two_sided_chart(
      debit_specs: debit_specs,
      credit_specs: [
        [ "currentLiabilities", "流動負債", "bs.current_liabilities",     "liability1" ],
        [ "fixedLiabilities",   "固定負債", "bs.non_current_liabilities", "liability2" ]
      ],
      equity: val("bs.equity"), equity_label: "純資産", base: base,
      unrenderable_note: "貸借対照表: データがない、または表示対応していないデータです。")
  end

  private
    # 固定資産は3分類の内訳で描くのが基本。ただし業種別の様式で固定資産を事業用資産として区分し、
    # 有形/無形の分類を持たない業種（電気・鉄道・電気通信の単体など）では内訳の合計が固定資産に
    # 遠く及ばない（投資その他の資産だけ標準タグで取れる）ため、固定資産合計の1段で描く。
    # 「内訳の合計が固定資産と合うか」で切り替えるのは、業種コードでなくデータの実態で判断するため
    # （一般事業会社で無形固定資産を開示しない企業などは、残りの2つで合計が合うので内訳のまま描ける）
    def fixed_asset_specs
      total = val("bs.non_current_assets")
      breakdown_total = FIXED_ASSET_BREAKDOWN.sum { |_, _, code, _| val(code).to_i }
      # 固定資産合計が取れない・ゼロの財務諸表は判断材料がないので従来どおり内訳で描く
      return FIXED_ASSET_BREAKDOWN if total.nil? || total.zero? || balanced?(total, breakdown_total)
      [ FIXED_ASSET_TOTAL ]
    end
end
