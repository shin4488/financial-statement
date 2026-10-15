# IFRS・経営指標の要約だけで作る形式
class Ingestion::Extractors::IfrsSummary < Ingestion::Extractors::Base
  def self.mapping = Ingestion::Mappings::IfrsSummary
end
