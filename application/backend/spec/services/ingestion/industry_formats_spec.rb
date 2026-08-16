require "rails_helper"

# 業種ごとに「形式判定 → 抽出 → チャート組み立て」を実XBRLで通し、
# 期待どおりの形式になり BS/PL/CF が描けることを確認する回帰テスト（取込〜表示の縦串）。
# 個々のタグ選択の検証は各Extractorのspec、Builderの組み立てルールは各Builderのspecに置く
RSpec.describe "業種別の形式判定と描画可否（実XBRL）" do
  CONS = Ingestion::Extractors::Base::CONSOLIDATED
  NON_CONS = Ingestion::Extractors::Base::NON_CONSOLIDATED

  # [docID, 企業, 連結/単体, 期待する形式, BS描画, PL描画, 備考]
  CASES = [
    [ "S100YDJC", "大成建設（建設）",             CONS,     "jgaap_general",   true,  true ],
    [ "S100YIHR", "東京電力HD（電気）",           CONS,     "jgaap_general",   true,  true,  "固定資産1段・営業費用一括" ],
    [ "S100YIHR", "東京電力HD（電気）",           NON_CONS, "jgaap_general",   true,  true,  "営業損失" ],
    [ "S100YE63", "東急（鉄道）",                 CONS,     "jgaap_general",   true,  true ],
    [ "S100YE63", "東急（鉄道）",                 NON_CONS, "jgaap_general",   true,  true ],
    [ "S100YC7N", "JR東日本（鉄道）",             NON_CONS, "jgaap_general",   true,  true,  "事業区分の合算" ],
    [ "S100Y9T5", "沖縄セルラー電話（電気通信）", CONS,     "jgaap_general",   true,  true,  "事業区分の合算・固定資産1段" ],
    [ "S100Y90D", "玉井商船（海運）",             CONS,     "jgaap_general",   true,  true ],
    [ "S100Y90D", "玉井商船（海運）",             NON_CONS, "jgaap_general",   true,  true,  "事業区分の合算" ],
    [ "S100XTDX", "静岡ガス（ガス）",             CONS,     "jgaap_general",   true,  true ],
    [ "S100XTDX", "静岡ガス（ガス）",             NON_CONS, "jgaap_general",   true,  true,  "ガス事業売上高" ],
    [ "S100YANQ", "いちよし証券（証券）",         CONS,     "jgaap_general",   true,  true,  "金融費用" ],
    [ "S100YI2V", "アサックス（特定金融）",       CONS,     "jgaap_general",   true,  true,  "営業費用一括（原価併記）" ],
    [ "S100YJB4", "小林洋行（商品先物）",         CONS,     "jgaap_general",   true,  true ],
    [ "S100Y0DB", "Mマート（投資業コード）",      NON_CONS, "jgaap_general",   true,  true,  "営業収益−営業費用型" ],
    [ "S100YD29", "かんぽ生命（保険）",           CONS,     "jgaap_insurance", true,  true ],
    [ "S100YD29", "かんぽ生命（保険）",           NON_CONS, "jgaap_insurance", true,  true ],
    [ "S100YCL0", "ソニーFG（保険）",             CONS,     "jgaap_insurance", true,  true ],
    [ "S100YCL0", "ソニーFG（保険）",             NON_CONS, "jgaap_general",   true,  true,  "業種コードinsでも流動資産があれば一般（持株会社の単体）" ],
    [ "S100YE7T", "日本郵政（bnk,ins）",          CONS,     "jgaap_bank",      false, true,  "先頭の業種=銀行。貯金は企業拡張タグのためBSは描けない" ]
  ].freeze

  CASES.each do |doc_id, name, consolidation, expected_format, bs_ok, pl_ok, note|
    it "#{name} #{consolidation.empty? ? '連結' : '単体'} → #{expected_format}#{note && "（#{note}）"}" do
      xbrl = load_xbrl_fixture(doc_id)
      dei = Ingestion::DeiExtractor.new.extract(xbrl)
      # 単体は常に日本基準・単体の業種コードで判定する（ReportIngester#build_statementsと同じ規則）
      standard, industry = consolidation.empty? ? [ dei.accounting_standard, dei.consolidated_industry_code ]
                                                : [ "japan_gaap", dei.non_consolidated_industry_code ]
      format = Ingestion::FormatDetector.new.detect(xbrl, accounting_standard: standard,
                                                    industry_code: industry, consolidation: consolidation)
      expect(format).to eq expected_format

      items = Ingestion::FormatRegistry.extractor_for(format).new(xbrl, consolidation).extract
      fs = build(:disclosure_financial_statement, presentation_format: format)
      allow(fs).to receive(:items_hash).and_return(items)
      charts = Charts::BuilderRegistry.build_all(fs)
      aggregate_failures do
        expect(charts[:balance_sheet].renderable).to be(bs_ok), "BS: #{charts[:balance_sheet].note}"
        expect(charts[:profit_loss].renderable).to be(pl_ok), "PL: #{charts[:profit_loss].note}"
        # 単体はCFを作成しない企業が多いためCFは連結だけ確認する
        expect(charts[:cash_flow].renderable).to be(true) if consolidation.empty?
      end
    end
  end
end
