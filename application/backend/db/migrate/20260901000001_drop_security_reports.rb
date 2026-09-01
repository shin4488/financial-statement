# 旧系統（SecurityReport系）の凍結データ。新系統との突き合わせ検証を終えたため、本番はpg_dumpでバックアップした上で削除する
# バックアップ: 本番VPSの ~/backups/security_reports_20260901.sql.gz
# 復元コマンド（本番VPSのアプリディレクトリで実行。テーブル定義・データ・インデックス・外部キーごと復元される。参照先の companies テーブルが先に存在すること）:
#   gunzip -k ~/backups/security_reports_20260901.sql.gz
#   RAILS_ENV=production bundle exec rails runner 'c = ActiveRecord::Base.connection_db_config.configuration_hash; exec({ "PGPASSWORD" => c[:password].to_s }, "psql", "-h", (c[:host] || "localhost").to_s, "-p", (c[:port] || 5432).to_s, "-U", c[:username].to_s, "-d", c[:database].to_s, "-f", "#{Dir.home}/backups/security_reports_20260901.sql")'
class DropSecurityReports < ActiveRecord::Migration[7.2]
  def change
    drop_table :security_reports
  end
end
