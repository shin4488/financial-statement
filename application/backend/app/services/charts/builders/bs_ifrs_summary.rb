# IFRS・詳細タグなし: 経営指標サマリで実値が取れるBS科目は資産合計と親会社所有者帰属持分だけで、
# 負債を実値で示せない（導出すると非支配持分が混ざる）ため、チャートは描かず理由を説明する。
# 形式判定は「資産合計タグの不存在」なので、詳細タグ付けが義務になった後の有報がこの形式になる可能性も残る。
# そのため、義務になる前（2019年3月31日より前に終わる事業年度）と決算日で確かめられたときだけ、年度を理由に書く。
# 決算月は会社で違うため「3月期」ではなく「3月末」と書く
class Charts::Builders::BsIfrsSummary < Charts::Builders::StackBase
  DETAILED_TAGGING_START = Date.new(2019, 3, 31)

  def build
    if @fiscal_year_end_date && @fiscal_year_end_date < DETAILED_TAGGING_START
      Charts::StackChart.unrenderable("財政状態計算書: 2019年3月末より前のIFRSは非対応です。")
    else
      Charts::StackChart.unrenderable("財政状態計算書: 詳細データがないため表示できません。")
    end
  end
end
