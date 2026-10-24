# 実XBRLフィクスチャ（数MB/件）はリポジトリにコミットしないため、取得していない環境（CIなど）ではspecをskipする
module XbrlFixtures
  DIR = File.expand_path("../fixtures/xbrl", __dir__)

  # フィクスチャのパスを返す。未取得ならそのexampleをskipする
  def require_xbrl_fixture(doc_id)
    path = File.join(DIR, "#{doc_id}.xbrl")
    skip "実XBRLフィクスチャ #{doc_id}.xbrl が未取得（spec/fixtures/xbrl/README.md 参照）" unless File.exist?(path)
    path
  end

  def load_xbrl_fixture(doc_id)
    Xbrl::Document.load(require_xbrl_fixture(doc_id))
  end
end

RSpec.configure { |config| config.include XbrlFixtures }
