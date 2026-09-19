module Ingestion
  module Extractors
    # 純資産には新株予約権・非支配株主持分等が含まれるため、自己資本として代用しない。
    # 株主資本 + 評価・換算差額等（連結ではその他の包括利益累計額）から取得する。
    # Baseのマッピング式と同じevaluate/rounding_error契約で3つの日本基準形式から共用する。
    class JgaapOwnersEquity
      SHAREHOLDERS = "jppfs_cor:ShareholdersEquity".freeze
      ADJUSTMENTS = %w[jppfs_cor:ValuationAndTranslationAdjustments jppfs_cor:AccumulatedOtherComprehensiveIncome].freeze
      NET_ASSETS = "jppfs_cor:NetAssets".freeze
      EXCLUDED = %w[jppfs_cor:SubscriptionRightsToShares jppfs_cor:ShareAwardRights jppfs_cor:NonControllingInterests].freeze

      def evaluate(xbrl, context)
        tags = source_tags(xbrl, context)
        tags&.sum { |tag| xbrl.money(tag, context) }
      end

      def rounding_error(xbrl, context)
        errors = source_tags(xbrl, context)&.map { |tag| xbrl.rounding_error(tag, context) }
        errors.sum if errors && errors.none?(&:nil?)
      end

      private
        def source_tags(xbrl, context)
          shareholders = xbrl.money(SHAREHOLDERS, context)
          return if shareholders.nil?
          adjustment = ADJUSTMENTS.find { |tag| !xbrl.money(tag, context).nil? }
          return [ SHAREHOLDERS, adjustment ] if adjustment
          # 調整項目がゼロならタグが省略/nilになる有報もある。純資産の内訳を検算して判別する。
          # 新株予約権・株式引受権・非支配持分を除けば株主資本と一致するときだけ採用し、
          # 説明できない欠損を0で補わない。切捨て開示の差は各タグの精度の範囲内だけ許容する。
          net_assets = xbrl.money(NET_ASSETS, context)
          return if net_assets.nil?
          parts = [ SHAREHOLDERS ] + EXCLUDED.select { |tag| !xbrl.money(tag, context).nil? }
          difference = (net_assets - parts.sum { |tag| xbrl.money(tag, context) }).abs
          errors = ([ NET_ASSETS ] + parts).map { |tag| xbrl.rounding_error(tag, context) }
          matches = difference.zero? || (errors.none?(&:nil?) && difference < errors.sum)
          [ SHAREHOLDERS ] if matches
        end
    end
  end
end
