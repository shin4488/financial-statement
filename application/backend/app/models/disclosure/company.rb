# モデル群を Disclosure 名前空間に置く理由:
#   - Railsアプリのモジュール名が FinancialStatement のため、トップレベルに
#     FinancialStatement モデルを定義できない（moduleとclassの衝突でTypeErrorになる）
#   - トップレベルの Company（SecurityReport系）と共存させるため
module Disclosure
  class Company < ApplicationRecord
    # companies テーブルは SecurityReport 系機能と共用する（企業マスタを二重に持たない）。
    # カラム名の差異は alias で吸収し、この名前空間内では name_ja / name_en の語彙で扱う
    self.table_name = "companies"
    alias_attribute :name_ja, :company_japanese_name
    alias_attribute :name_en, :company_english_name

    has_many :reports, class_name: "Disclosure::Report", foreign_key: :company_id
  end
end
