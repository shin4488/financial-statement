import React from 'react';
import { CashFlowBarChartProps } from './props';
import WaterFlowBarChart from '@/components/waterFlowBarChart/WaterFlowBarChart';
import { WaterFlowBarChartElement } from '@/components/waterFlowBarChart/props';
import ChartAlternative from '@/components/chartAlternative/ChartAlternative';

export default class CashFlowBarChart extends React.Component<CashFlowBarChartProps> {
  waterFlowBarChartData(): WaterFlowBarChartElement[] {
    const startingCash = this.props.startingCash;
    const operatingActivitiesCashFlow = this.props.operatingActivitiesCashFlow;
    const investingActivitiesCashFlow = this.props.investingActivitiesCashFlow;
    const financingActivitiesCashFlow = this.props.financingActivitiesCashFlow;
    return [
      // sumの部分が透明となるため、sumは前の要素までの合計値とする
      { name: '期首残', value: startingCash, previousSum: 0 },
      {
        name: '営業CF',
        value: operatingActivitiesCashFlow,
        previousSum: startingCash,
      },
      {
        name: '投資CF',
        value: investingActivitiesCashFlow,
        previousSum: startingCash + operatingActivitiesCashFlow,
      },
      {
        name: '財務CF',
        value: financingActivitiesCashFlow,
        previousSum:
          startingCash +
          operatingActivitiesCashFlow +
          investingActivitiesCashFlow,
      },
      {
        name: '期末残',
        value: this.props.endingCash,
        previousSum: 0,
      },
    ];
  }

  hasNoData(): boolean {
    return (
      this.props.startingCash === 0 &&
      this.props.operatingActivitiesCashFlow === 0 &&
      this.props.investingActivitiesCashFlow === 0 &&
      this.props.financingActivitiesCashFlow === 0
    );
  }

  render(): React.ReactNode {
    if (this.hasNoData()) {
      return (
        <ChartAlternative>
          キャッシュフロー計算書: データがありません。
        </ChartAlternative>
      );
    }

    const waterFlowBarChartData = this.waterFlowBarChartData();
    return (
      <WaterFlowBarChart
        data={waterFlowBarChartData}
        positiveColor="#A1C2F1"
        negativeColor="#FF9EAA"
        unit="円"
      />
    );
  }
}
