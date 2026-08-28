# IFRS・詳細タグなし: 経営指標サマリで実値が取れるBS科目は資産合計と親会社所有者帰属持分だけで、
# 負債を実値で示せない（導出すると非支配持分が混ざる）ため、チャートは描かず理由を説明する
class Charts::Builders::BsIfrsSummary < Charts::Builders::StackBase
  def build
    Charts::StackChart.unrenderable(
      "財政状態計算書: 2019年3月期より前の有報には財政状態計算書の詳細データが収録されていないため表示できません。")
  end
end
