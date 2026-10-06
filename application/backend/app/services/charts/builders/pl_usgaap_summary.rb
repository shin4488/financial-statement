# 米国基準: 損益計算書の明細にタグがなく、経営指標の要約の売上と税引前利益だけが取れる。
# 費用は「売上−税引前利益」の差額でしか求められないため描かない
class Charts::Builders::PlUsgaapSummary < Charts::Builders::StackBase
  def build = Charts::StackChart.unrenderable("損益計算書: 米国基準は非対応です。")
end
