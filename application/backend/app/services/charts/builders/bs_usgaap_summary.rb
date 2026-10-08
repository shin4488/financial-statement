# 米国基準: 経営指標の要約には資産合計と純資産しかなく、負債は差額でしか出せない。
# 負債と資本の間に償還可能非支配持分がある会社では差額にそれも入り、要約からは有無を判別できないため描かない
class Charts::Builders::BsUsgaapSummary < Charts::Builders::StackBase
  def build = Charts::StackChart.unrenderable("貸借対照表: 米国基準は非対応です。")
end
