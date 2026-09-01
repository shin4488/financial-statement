# 旧系統の凍結データ。新系統との突き合わせ検証を終えたため、本番はpg_dumpでバックアップした上で削除する
class DropSecurityReports < ActiveRecord::Migration[7.2]
  def change
    drop_table :security_reports
  end
end
