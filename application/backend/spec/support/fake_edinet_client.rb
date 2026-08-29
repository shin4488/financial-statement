# Edinet::Client の代役。ReportIngester#ingest（公開API）をEDINET非接続で通すために、
# 与えられたXBRL文字列をwork_dirへ書き出してパスを返す。
# ingestは取込後にファイルを消すため、実フィクスチャを直接渡さず毎回書き出す
class FakeEdinetClient
  # xml_by_doc_id: { "S0000001" => "<xbrl…>", "S0000002" => nil, ... }（nil = XBRLを含まない書類）
  def initialize(xml_by_doc_id)
    @xml_by_doc_id = xml_by_doc_id
  end

  def download_xbrl(doc_id:, work_dir:)
    xml = @xml_by_doc_id.fetch(doc_id)
    return nil if xml.nil?
    path = File.join(work_dir, "#{doc_id}.xbrl")
    File.write(path, xml)
    path
  end
end

# 実XBRLフィクスチャをwork_dirへコピーして返す版（取込〜表示の縦串スペック用）
class FixtureEdinetClient
  def download_xbrl(doc_id:, work_dir:)
    path = File.join(work_dir, "#{doc_id}.xbrl")
    FileUtils.cp(File.join(XbrlFixtures::DIR, "#{doc_id}.xbrl"), path)
    path
  end
end
