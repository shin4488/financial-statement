# IFRS・流動/非流動分類BS
class Ingestion::Extractors::IfrsClassified < Ingestion::Extractors::Base
  def self.mapping = Ingestion::Mappings::IfrsClassified
end
