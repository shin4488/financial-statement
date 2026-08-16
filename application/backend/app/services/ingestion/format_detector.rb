# （FormatRegistryとは別ファイル: Zeitwerkはクラス名とファイル名の一致を要求する）
module Ingestion
  class FormatDetector
    # 日本基準で、一般事業会社と財務諸表の骨格そのものが違う業種だけを列挙する
    # （流動/固定の区分がなく、PLも売上高でなく経常収益から始まる金融機関の様式）。
    # ここに無い業種（建設・鉄道・電気・ガス・海運・電気通信・証券・特定金融・商品先物・投資業など）も
    # 業種別の勘定科目を持つが、骨格は一般と同じなので一般形式で扱い、タグ名の違いは
    # Extractorのフォールバックで吸収する（対応表は docs/guide/07_taxonomy_mapping.md）
    FINANCIAL_INSTITUTION_FORMATS = {
      "bnk" => FormatRegistry::JGAAP_BANK,      # 銀行・信託業
      "ins" => FormatRegistry::JGAAP_INSURANCE  # 生命保険業・損害保険業
    }.freeze

    # consolidation は Extractors::Base::CONSOLIDATED / NON_CONSOLIDATED
    def detect(xbrl, accounting_standard:, industry_code:, consolidation:)
      case accounting_standard
      when "japan_gaap"
        detect_jgaap(xbrl, industry_code, consolidation)
      when "ifrs"
        # IFRSのBS 2様式（流動/非流動 511000・流動性配列 512000）はDEIでは区別できないため
        # 「流動資産合計タグの実在」で判定する（流動性配列の様式には流動/非流動の合計要素自体が存在しない）。
        # moneyがnil = タグ自体がない or 数値でない、のどちらでも流動性配列側に倒れるが、
        # その場合BsIfrsLiquidityは合計科目だけで描けるため安全側の誤判定になる
        if xbrl.money("jpigp_cor:CurrentAssetsIFRS", "CurrentYearInstant#{consolidation}")
          FormatRegistry::IFRS_CLASSIFIED
        else
          FormatRegistry::IFRS_LIQUIDITY
        end
      else
        # us_gaap: 本表の詳細タグがEDINETタクソノミに存在しない（企業拡張タグのみ）
        FormatRegistry::UNSUPPORTED
      end
    end

    private
      def detect_jgaap(xbrl, industry_code, consolidation)
        # 業種DEIコードは大文字小文字が揺れる（"bnk"と"INS"の両方が存在する）。
        # 複数の業種別規則を適用する企業はカンマ区切りで並ぶ（例: "bnk,ins"）ため、先頭を主たる業種とみなす
        primary_industry = industry_code.to_s.downcase.split(",").first
        format = FINANCIAL_INSTITUTION_FORMATS.fetch(primary_industry, FormatRegistry::JGAAP_GENERAL)
        return format if format == FormatRegistry::JGAAP_GENERAL

        # 業種コードが銀行・保険でも、流動資産タグを持つ財務諸表は一般事業会社の様式で作られている
        # （銀行・保険持株会社の単体財務諸表など。金融機関の様式には流動/固定の区分自体がない）。
        # DEIの業種コードは提出者が付けるため、様式はタグの実在で確かめる
        if xbrl.money("jppfs_cor:CurrentAssets", "CurrentYearInstant#{consolidation}")
          FormatRegistry::JGAAP_GENERAL
        else
          format
        end
      end
  end
end
