# 米国基準・経営指標の要約だけで作る形式
class Ingestion::Extractors::UsgaapSummary < Ingestion::Extractors::Base
  def self.mapping = Ingestion::Mappings::UsgaapSummary
end
