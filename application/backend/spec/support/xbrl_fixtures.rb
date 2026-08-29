# 実XBRLフィクスチャ（コミット済み。実際の有報から rake fixtures:refresh_xbrl で
# テストが読む範囲だけに間引いたもの。間引きの条件は lib/tasks/fixtures.rake）
module XbrlFixtures
  DIR = File.expand_path("../fixtures/xbrl", __dir__)

  # フィクスチャのパスを返す。コミット済みのため、無い=チェックアウトが壊れているか
  # 取得漏れであり、skipで緑にせず失敗として気づかせる
  def require_xbrl_fixture(doc_id)
    path = File.join(DIR, "#{doc_id}.xbrl")
    raise "実XBRLフィクスチャ #{doc_id}.xbrl がありません（rake fixtures:refresh_xbrl で取得。spec/fixtures/xbrl/README.md 参照）" unless File.exist?(path)
    path
  end

  def load_xbrl_fixture(doc_id)
    Xbrl::Document.load(require_xbrl_fixture(doc_id))
  end
end

RSpec.configure { |config| config.include XbrlFixtures }
