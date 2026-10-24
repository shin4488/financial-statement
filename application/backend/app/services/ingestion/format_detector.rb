module Ingestion
  class FormatDetector
    # 日本基準で、一般事業会社と財務諸表の骨格そのものが違う業種だけを列挙する（流動/固定の区分がなく、PLも売上高でなく経常収益から始まる金融機関の様式）。
    # ここに無い業種（建設・鉄道・電気・ガス・海運・電気通信・証券・特定金融・商品先物・投資業など）も業種別の勘定科目を持つが、骨格は一般と同じなので一般形式で扱い、タグ名の違いは対応表のフォールバックで吸収する
    FINANCIAL_INSTITUTION_FORMATS = {
      "bnk" => FinancialStatements::Formats::JGAAP_BANK,      # 銀行・信託業
      "ins" => FinancialStatements::Formats::JGAAP_INSURANCE  # 生命保険業・損害保険業
    }.freeze

    # consolidation は :consolidated・:non_consolidated
    def detect(xbrl, accounting_standard:, industry_code:, consolidation:)
      case accounting_standard
      when "japan_gaap"
        detect_jgaap(xbrl, industry_code, consolidation)
      when "ifrs"
        # IFRSのBS 2様式（流動/非流動 511000・流動性配列 512000）はDEIでは区別できないため
        # 「流動資産合計タグの実在」で判定する（流動性配列の様式には流動/非流動の合計要素自体が存在しない）。
        # さらに資産合計タグすら無い書類は、本表の詳細タグ付けが行われる前
        # （義務化は2019年3月31日以後終了事業年度から）の有報で jpigp_cor のfact自体が
        # 収録されていないため、経営指標サマリだけで構成する形式に落とす
        if xbrl.money("jpigp_cor:CurrentAssetsIFRS", current_instant(consolidation))
          FinancialStatements::Formats::IFRS_CLASSIFIED
        elsif xbrl.money("jpigp_cor:AssetsIFRS", current_instant(consolidation))
          FinancialStatements::Formats::IFRS_LIQUIDITY
        else
          FinancialStatements::Formats::IFRS_SUMMARY
        end
      when "us_gaap"
        # 本表の詳細タグがEDINETタクソノミに存在しない（企業拡張タグのみ）ため、
        # 標準タグのある経営指標の要約だけで構成する形式にする
        FinancialStatements::Formats::USGAAP_SUMMARY
      else
        FinancialStatements::Formats::UNSUPPORTED
      end
    end

    private
      def detect_jgaap(xbrl, industry_code, consolidation)
        # 業種DEIコードは大文字小文字が揺れる（"bnk"と"INS"の両方が存在する）。
        # 複数の業種別規則を適用する企業はカンマ区切りで並ぶ（例: "bnk,ins"）ため、先頭を主たる業種とみなす
        industries = industry_code.to_s.downcase.split(",")
        format = FINANCIAL_INSTITUTION_FORMATS.fetch(industries.first, FinancialStatements::Formats::JGAAP_GENERAL)
        return format if format == FinancialStatements::Formats::JGAAP_GENERAL

        # 業種コードが銀行・保険でも、流動資産タグを持つ財務諸表は一般事業会社の様式で作られている
        # （銀行・保険持株会社の単体財務諸表など。金融機関の様式には流動/固定の区分自体がない）。
        # DEIの業種コードは提出者が付けるため、様式はタグの実在で確かめる
        return FinancialStatements::Formats::JGAAP_GENERAL if xbrl.money("jppfs_cor:CurrentAssets", current_instant(consolidation))

        # 銀行と保険を並べる会社は、先頭の業種の様式で財務諸表を作っているとは限らない。
        # 様式ごとに経常収益のタグが違うため、並んだ金融機関の業種のうち、経常収益のタグがある最初の様式にする
        financial_formats = industries.filter_map { |industry| FINANCIAL_INSTITUTION_FORMATS[industry] }.uniq
        financial_formats.find { |candidate| ordinary_revenue?(xbrl, candidate, consolidation) } || format
      end

      # 経常収益のタグは、その様式の対応表を使う（タグ名を二重に持たない）。形式を決めるだけなので金額だけを読み、端数は読まない
      def ordinary_revenue?(xbrl, format, consolidation)
        expression = Mappings.for(format).expression("pl.ordinary_revenue")
        !expression.amount(xbrl, period: :duration, consolidation: consolidation).nil?
      end

      def current_instant(consolidation) = Xbrl::ReportingPeriod.context_id(:instant, consolidation)
  end
end
