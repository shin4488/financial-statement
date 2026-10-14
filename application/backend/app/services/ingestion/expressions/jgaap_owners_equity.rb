module Ingestion
  module Expressions
    # 自己資本（日本基準）。純資産には新株予約権・非支配株主持分等が含まれるため、自己資本として代用しない。
    # 株主資本 + 評価・換算差額等（連結ではその他の包括利益累計額）から取得する
    class JgaapOwnersEquity
      # 信金中央金庫は株主資本に相当する「会員勘定合計」を銀行用の標準タグで開示する。
      SHAREHOLDERS = %w[jppfs_cor:ShareholdersEquity jppfs_cor:ShareholdersEquityShinkinBNK].freeze
      ADJUSTMENTS = %w[jppfs_cor:ValuationAndTranslationAdjustments jppfs_cor:AccumulatedOtherComprehensiveIncome].freeze
      NET_ASSETS = "jppfs_cor:NetAssets".freeze
      EXCLUDED = %w[jppfs_cor:SubscriptionRightsToShares jppfs_cor:ShareAwardRights jppfs_cor:NonControllingInterests].freeze

      def amount(source, period:, consolidation:)
        context = Xbrl::ReportingPeriod.context_id(period, consolidation)
        source_tags(source, context)&.sum { |tag| source.money(tag, context) }
      end

      # 端数の上限は使ったタグの端数の和。精度が不明なタグがあれば不明（nil）
      def evaluate(source, period:, consolidation:)
        context = Xbrl::ReportingPeriod.context_id(period, consolidation)
        tags = source_tags(source, context)
        return unless tags
        errors = tags.map { |tag| source.rounding_error(tag, context) }
        Measured.new(tags.sum { |tag| source.money(tag, context) }, (errors.sum if errors.none?(&:nil?)))
      end

      # 複数のタグから求める科目で、表の「－」を確かめる対象にしない
      def blank?(source, period:, consolidation:) = false

      private
        def source_tags(source, context)
          shareholders = SHAREHOLDERS.find { |tag| !source.money(tag, context).nil? }
          return unless shareholders
          adjustment = ADJUSTMENTS.find { |tag| !source.money(tag, context).nil? }
          return [ shareholders, adjustment ] if adjustment
          # 調整項目がゼロならタグが省略/nilになる有報もある。純資産の内訳を検算して判別する。
          # 新株予約権・株式引受権・非支配持分を除けば株主資本と一致するときだけ採用し、
          # 説明できない欠損を0で補わない。
          net_assets = source.money(NET_ASSETS, context)
          return if net_assets.nil?
          parts = [ shareholders ] + EXCLUDED.select { |tag| !source.money(tag, context).nil? }
          difference = net_assets - parts.sum { |tag| source.money(tag, context) }
          errors = ([ NET_ASSETS ] + parts).map { |tag| source.rounding_error(tag, context) }
          [ shareholders ] if FinancialStatements::RoundingRange.within?(difference, errors)
        end
    end
  end
end
