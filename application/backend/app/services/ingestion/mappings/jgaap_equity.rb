# 日本基準の自己資本。株主資本＋評価・換算差額等を、純資産の内訳で検算して求める（取得式は Ingestion::Expressions::JgaapOwnersEquity）
Ingestion::Mappings::JgaapEquity = Ingestion::Mappings::Section.define do
  item "bs.equity_attributable_to_owners", Ingestion::Expressions::JgaapOwnersEquity.new
end
