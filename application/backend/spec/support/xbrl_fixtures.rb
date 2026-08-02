# 実XBRLフィクスチャ（数MB/件）はリポジトリにコミットしない前提のため、
# 存在しない環境ではspecをskipする（CI等で必要になったら取得タスクを実行する）。
# 取得方法は spec/fixtures/xbrl/README.md を参照
module XbrlFixtures
  DIR = File.expand_path("../fixtures/xbrl", __dir__)

  def load_xbrl_fixture(doc_id)
    path = File.join(DIR, "#{doc_id}.xbrl")
    skip "実XBRLフィクスチャ #{doc_id}.xbrl が未取得（spec/fixtures/xbrl/README.md 参照）" unless File.exist?(path)
    Xbrl::Document.load(path)
  end
end

RSpec.configure { |config| config.include XbrlFixtures }
