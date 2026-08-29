require "rails_helper"

# 業種ごとに「取込（形式判定・抽出・保存）→ チャート組み立て」を実XBRLで通し、
# 期待どおりの形式になり BS/PL/CF が描けることを確認する回帰テスト（取込〜表示の縦串）。
# ReportIngester#ingest（公開API）を通すので、連結/単体それぞれの判定規則も実装側のものがそのまま検証される。
# 個々のタグ選択の検証は各Extractorのspec、Builderの組み立てルールは各Builderのspecに置く
RSpec.describe "業種別の形式判定と描画可否（実XBRL）" do
  # 期待値は { 連結/単体 => [形式, BS描画, PL描画] }。書いた区分だけ検証する
  # （単体はCFを作成しない企業が多いため、CFは連結だけ確認する）
  cases = [
    [ "S100YDJC", "大成建設（建設）",
      { consolidated: [ "jgaap_general", true, true ] } ],
    [ "S100YIHR", "東京電力HD（電気）",
      { consolidated: [ "jgaap_general", true, true ], non_consolidated: [ "jgaap_general", true, true ] },
      "固定資産1段・営業費用一括。単体は営業損失" ],
    [ "S100YE63", "東急（鉄道）",
      { consolidated: [ "jgaap_general", true, true ], non_consolidated: [ "jgaap_general", true, true ] } ],
    [ "S100YC7N", "JR東日本（鉄道）",
      { non_consolidated: [ "jgaap_general", true, true ] }, "事業区分の合算" ],
    [ "S100Y9T5", "沖縄セルラー電話（電気通信）",
      { consolidated: [ "jgaap_general", true, true ] }, "事業区分の合算・固定資産1段" ],
    [ "S100Y90D", "玉井商船（海運）",
      { consolidated: [ "jgaap_general", true, true ], non_consolidated: [ "jgaap_general", true, true ] },
      "単体は事業区分の合算" ],
    [ "S100XTDX", "静岡ガス（ガス）",
      { consolidated: [ "jgaap_general", true, true ], non_consolidated: [ "jgaap_general", true, true ] },
      "単体はガス事業売上高" ],
    [ "S100YANQ", "いちよし証券（証券）",
      { consolidated: [ "jgaap_general", true, true ] }, "金融費用" ],
    [ "S100YI2V", "アサックス（特定金融）",
      { consolidated: [ "jgaap_general", true, true ] }, "営業費用一括（原価併記）" ],
    [ "S100YJB4", "小林洋行（商品先物）",
      { consolidated: [ "jgaap_general", true, true ] } ],
    [ "S100Y0DB", "Mマート（投資業コード）",
      { non_consolidated: [ "jgaap_general", true, true ] }, "営業収益−営業費用型" ],
    [ "S100YD29", "かんぽ生命（保険）",
      { consolidated: [ "jgaap_insurance", true, true ], non_consolidated: [ "jgaap_insurance", true, true ] } ],
    [ "S100YCL0", "ソニーFG（保険）",
      { consolidated: [ "jgaap_insurance", true, true ], non_consolidated: [ "jgaap_general", true, true ] },
      "業種コードinsでも流動資産があれば一般（持株会社の単体）" ],
    [ "S100YE7T", "日本郵政（bnk,ins）",
      { consolidated: [ "jgaap_bank", false, true ] }, "先頭の業種=銀行。貯金は企業拡張タグのためBSは描けない" ]
  ]

  cases.each do |doc_id, name, expectations, note|
    it "#{name} → #{expectations.map { |c, (f, _, _)| "#{c == :consolidated ? '連結' : '単体'}=#{f}" }.join(' / ')}#{note && "（#{note}）"}" do
      require_xbrl_fixture(doc_id)
      Dir.mktmpdir do |work_dir|
        Ingestion::ReportIngester.new(client: FixtureEdinetClient.new)
                                 .ingest(doc_id: doc_id, work_dir: work_dir)
      end

      expectations.each do |consolidation_type, (expected_format, bs_ok, pl_ok)|
        fs = Disclosure::FinancialStatement.find_by!(consolidation_type: consolidation_type)
        charts = Charts::BuilderRegistry.build_all(fs)
        aggregate_failures("#{consolidation_type}") do
          expect(fs.presentation_format).to eq expected_format
          expect(charts[:balance_sheet].renderable).to be(bs_ok), "BS: #{charts[:balance_sheet].note}"
          expect(charts[:profit_loss].renderable).to be(pl_ok), "PL: #{charts[:profit_loss].note}"
          expect(charts[:cash_flow].renderable).to be(true) if consolidation_type == :consolidated
        end
      end
    end
  end
end
