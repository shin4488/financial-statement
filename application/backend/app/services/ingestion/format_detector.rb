# （FormatRegistryとは別ファイル: Zeitwerkはクラス名とファイル名の一致を要求する）
module Ingestion
  class FormatDetector
    # 日本基準の業種DEIコード → 形式。未知の業種はunsupported（安全側）
    # cte=一般（電気通信含む汎用）, bnk=銀行。空値も一般扱い
    JGAAP_INDUSTRY_FORMATS = {
      nil => FormatRegistry::JGAAP_GENERAL,
      "" => FormatRegistry::JGAAP_GENERAL,
      "cte" => FormatRegistry::JGAAP_GENERAL,
      "bnk" => FormatRegistry::JGAAP_BANK
      # 保険・証券等は対象企業のXBRLでタグを確認した上でここに追加していく（例: "ins" => JGAAP_INSURANCE）
    }.freeze

    # consolidation は Extractors::Base::CONSOLIDATED / NON_CONSOLIDATED
    def detect(xbrl, accounting_standard:, industry_code:, consolidation:)
      case accounting_standard
      when "japan_gaap"
        # downcase する理由: 業種DEIコードは大文字小文字が揺れる
        # （"bnk"のような小文字と"INS"のような大文字の両方が存在する）
        JGAAP_INDUSTRY_FORMATS.fetch(industry_code&.downcase, FormatRegistry::UNSUPPORTED)
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
        FormatRegistry::UNSUPPORTED # us_gaap: 本表の詳細タグがEDINETタクソノミに存在しない
      end
    end
  end
end
