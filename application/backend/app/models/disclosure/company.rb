# モデル群を Disclosure 名前空間に置く理由:
#   - Railsアプリのモジュール名が FinancialStatement のため、トップレベルに
#     FinancialStatement モデルを定義できない（moduleとclassの衝突でTypeErrorになる）
module Disclosure
  class Company < ApplicationRecord
    # companies テーブルのカラム名の差異は alias で吸収し、
    # この名前空間内では name_ja / name_en の語彙で扱う
    self.table_name = "companies"
    alias_attribute :name_ja, :company_japanese_name
    alias_attribute :name_en, :company_english_name

    has_many :reports, class_name: "Disclosure::Report", foreign_key: :company_id
  end
end
