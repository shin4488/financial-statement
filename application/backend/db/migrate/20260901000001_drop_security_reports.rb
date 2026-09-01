# 旧系統の凍結データ。新系統との突き合わせ検証を終えたため、本番はpg_dumpでバックアップした上で削除する
# バックアップは本番VPSの ~/backups/security_reports_20260901.sql.gz（ローカルPCにもコピーあり）。
# gunzip -c で展開して psql に流せばテーブルごと復元できる（参照先の companies が先に存在すること）
class DropSecurityReports < ActiveRecord::Migration[7.2]
  def change
    drop_table :security_reports
  end
end
