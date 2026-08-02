# IFRS・流動性配列BS（タクソノミ様式512000。流動/非流動の要素自体が存在しない）
#
# IfrsClassified と似るが継承で差分定義しない（独立クラスとして定義する）:
# 形式間に継承関係を作ると片方の変更が他方に波及し、「形式ごとに独立して保守できる」
# 利点が消えるため。重複はマッピング定数のみで許容する
class Ingestion::Extractors::IfrsLiquidity < Ingestion::Extractors::Base
  INSTANT_MAPPING = {
    "bs.assets"                        => "jpigp_cor:AssetsIFRS",
    "bs.liabilities"                   => "jpigp_cor:LiabilitiesIFRS",
    "bs.equity"                        => "jpigp_cor:EquityIFRS",
    "bs.equity_attributable_to_owners" => "jpigp_cor:EquityAttributableToOwnersOfParentIFRS",
    "bs.non_controlling_interests"     => "jpigp_cor:NonControllingInterestsIFRS",
    "bs.cash_and_equivalents"          => "jpigp_cor:CashAndCashEquivalentsIFRS",
    "cf.cash_end"                      => "jpigp_cor:CashAndCashEquivalentsIFRS",
  }.freeze

  # PL/CFのタグ体系はBSの様式（511000/512000）と独立に共通であることを実測済みのため、
  # 意図的に定数を共有する。将来分岐したらコピーして独立させる
  DURATION_MAPPING = Ingestion::Extractors::IfrsClassified::DURATION_MAPPING

  private
    def extract_extras(result)
      put(result, "cf.cash_begin",
          @xbrl.money("jpigp_cor:CashAndCashEquivalentsIFRS", "Prior1YearInstant#{@c}"))
    end
end
