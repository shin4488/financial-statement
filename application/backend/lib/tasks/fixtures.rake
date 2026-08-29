# 実XBRLフィクスチャの取得と間引き。
# 有報XBRLは1件数MBあり大半がHTML本文（TextBlock）のため、テストが読む部分だけに間引いて
# コミットできるサイズ（1件数十〜数百KB）にする。値は実際の開示値のまま
module XbrlFixtureTasks
  FIXTURE_DIR = "spec/fixtures/xbrl".freeze
  # 取得対象のdocID。各書類の検証ポイントは spec/fixtures/xbrl/README.md の表を参照
  DOC_IDS = %w[
    S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO S100YQ6Y S100YR8L
    S100YDJC S100YIHR S100YC7N S100YE63 S100Y9T5 S100Y90D S100XTDX S100YANQ S100YI2V
    S100YJB4 S100Y0DB S100YD29 S100YCL0 S100YE7T S100SO41
  ].freeze

  # 残すfactの条件。アプリ（Xbrl::Document + Extractor）が読むのはこの範囲だけ:
  # - 参照するコンテキスト（当期・前期末・提出日。連結/単体とも）
  # - 標準タクソノミ4名前空間の要素（企業拡張タグはXbrl::Documentが読まない）
  # - 数値・短いテキストのfact（長文=TextBlockのHTML断片はテスト対象外）
  # 読む範囲を広げる変更をしたときは、この条件を合わせて refresh_xbrl で取り直すこと
  KEEP_CONTEXTS = %w[
    FilingDateInstant
    CurrentYearInstant CurrentYearInstant_NonConsolidatedMember
    CurrentYearDuration CurrentYearDuration_NonConsolidatedMember
    Prior1YearInstant Prior1YearInstant_NonConsolidatedMember
  ].freeze
  MAX_TEXT_LENGTH = 500

  module_function

  def slim(path)
    doc = File.open(path) { |f| Nokogiri::XML(f) { |cfg| cfg.huge } }
    doc.root.element_children.each do |el|
      context = el.attribute("contextRef")&.value
      standard_ns = Xbrl::Document::NS.values.any? { |pattern| el.namespace&.href&.match?(pattern) }
      keep = KEEP_CONTEXTS.include?(context) && standard_ns && el.text.to_s.strip.length <= MAX_TEXT_LENGTH
      el.remove unless keep
    end
    File.write(path, doc.to_xml)
  end
end

namespace :fixtures do
  desc "実XBRLフィクスチャをEDINETから取得し、間引いてspec/fixtures/xbrl/へ配置する（EDINET_API_KEYが必要）"
  task refresh_xbrl: :environment do
    client = Edinet::Client.new
    Dir.mktmpdir("fixtures") do |work_dir|
      XbrlFixtureTasks::DOC_IDS.each do |doc_id|
        downloaded = client.download_xbrl(doc_id: doc_id, work_dir: work_dir)
        dest = File.join(XbrlFixtureTasks::FIXTURE_DIR, "#{doc_id}.xbrl")
        FileUtils.mv(downloaded, dest)
        XbrlFixtureTasks.slim(dest)
        puts "#{doc_id}: #{File.size(dest)} bytes"
        sleep(Ingestion::DailyIngestionService::THROTTLE_SECONDS) # EDINETのレート制限（403）対策
      end
    end
  end

  desc "spec/fixtures/xbrl/ にある取得済みXBRLを間引く（refresh_xbrlの間引き部分だけ。冪等）"
  task slim_xbrl: :environment do
    Dir.glob(File.join(XbrlFixtureTasks::FIXTURE_DIR, "*.xbrl")).sort.each do |path|
      XbrlFixtureTasks.slim(path)
      puts "#{File.basename(path)}: #{File.size(path)} bytes"
    end
  end
end
