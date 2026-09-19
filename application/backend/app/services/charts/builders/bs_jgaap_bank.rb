# 内訳の網羅性を確定できない形式は、開示された合計で構成を示す。
class Charts::Builders::BsJgaapBank < Charts::Builders::StackBase
  def build
    two_sided_chart(
      debit_specs: [ [ "assets", "資産合計", "bs.assets", "asset1" ] ],
      credit_specs: [ [ "liabilities", "負債合計", "bs.liabilities", "liability1" ] ],
      equity: val("bs.equity"), equity_label: "純資産", base: val("bs.assets"),
      unrenderable_note: no_data_note("貸借対照表"))
  end
end
