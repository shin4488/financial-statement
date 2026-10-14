module FinancialStatements
  # チャートの丸め済み比率やセグメントを逆算せず、保存済みの金額から各指標を独立に計算する。
  # 売上高がなくてもROE/ROAは算出できる。利益の欠損を別の利益定義や0で補わない。
  class Indicators
    Metric = Struct.new(:value, :status, :source, keyword_init: true)

    # StatementData を受ける。items_hash・consolidated?・disclosed_roe を持つ値（ARモデルなど）も受け、その3つだけを読む
    def self.build(statement)
      new(statement.is_a?(StatementData) ? statement : statement_data_from(statement)).build
    end

    def self.statement_data_from(source)
      items = source.items_hash
      # StatementData は端数の表を持つ Amounts を受けるため、普通のHashは端数の表が空の Amounts に詰め替える
      amounts = items.is_a?(Amounts) ? items : Amounts.new.merge!(items)
      StatementData.new(consolidation_type: source.consolidated? ? :consolidated : :non_consolidated,
                        accounting_standard: nil, presentation_format: nil, amounts: amounts,
                        disclosed_roe: source.disclosed_roe, fiscal_year_end_date: nil)
    end
    private_class_method :statement_data_from

    def initialize(statement)
      @items = statement.amounts
      @disclosed_roe = statement.disclosed_roe
      @profit_code = statement.consolidated? ? "pl.profit_attributable_to_owners" : "pl.profit"
    end

    def build
      profit = @items[@profit_code]
      revenue = @items["pl.revenue"]
      assets = average("bs.assets_begin", "bs.assets")
      equity = average("bs.equity_attributable_to_owners_begin", "bs.equity_attributable_to_owners")
      {
        roe: roe(profit, equity),
        roa: ratio(profit, assets),
        net_profit_margin: ratio(profit, revenue),
        asset_turnover: ratio(revenue, assets),
        financial_leverage: ratio(assets, equity)
      }
    end

    private
      # 算出不可（平均自己資本が0以下）は欠損と区別し、公表値で隠さない。
      def roe(profit, equity)
        return Metric.new(status: "not_calculable") if equity && !equity.positive?
        calculated = ratio(profit, equity)
        return calculated unless calculated.status == "missing_data" && @disclosed_roe&.finite?
        value = @disclosed_roe.to_f
        return calculated unless value.finite?
        Metric.new(value: value, status: "available", source: "disclosed")
      end

      def average(opening, closing)
        values = @items.values_at(opening, closing)
        values.sum / 2.to_d if values.none?(&:nil?)
      end

      def ratio(numerator, denominator)
        return Metric.new(status: "missing_data") if numerator.nil? || denominator.nil?
        return Metric.new(status: "not_calculable") unless denominator.positive?
        value = (numerator.to_d / denominator).to_f
        return Metric.new(status: "not_calculable") unless value.finite?
        # APIは倍率を返す（0.16 = 16%）。中間結果を丸めず、表示時だけ桁を揃える。
        Metric.new(value: value, status: "available", source: "calculated")
      end
  end
end
