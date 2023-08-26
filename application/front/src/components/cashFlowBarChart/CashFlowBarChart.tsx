import React from 'react';
import { CashFlowBarChartProps } from './props';
import WaterFlowBarChart from '@/components/waterFlowBarChart/WaterFlowBarChart';
import { WaterFlowBarChartElement } from '@/components/waterFlowBarChart/props';

export default class CashFlowBarChart extends React.Component<CashFlowBarChartProps> {
  waterFlowBarChartData(): WaterFlowBarChartElement[] {
    const openingBalance = this.props.openingBalance;
    const operatingActivitiesCashFlow = this.props.operatingActivitiesCashFlow;
    const investingActivitiesCashFlow = this.props.investingActivitiesCashFlow;
    const financingActivitiesCashFlow = this.props.financingActivitiesCashFlow;
    return [
      // sumの部分が透明となるため、sumは前の要素までの合計値とする
      { name: '期首残高', value: openingBalance, previousSum: 0 },
      {
        name: '営業CF',
        value: operatingActivitiesCashFlow,
        previousSum: openingBalance,
      },
      {
        name: '投資CF',
        value: investingActivitiesCashFlow,
        previousSum: openingBalance + operatingActivitiesCashFlow,
      },
      {
        name: '財務CF',
        value: financingActivitiesCashFlow,
        previousSum:
          openingBalance +
          operatingActivitiesCashFlow +
          investingActivitiesCashFlow,
      },
      {
        name: '期末残高',
        value:
          openingBalance +
          operatingActivitiesCashFlow +
          investingActivitiesCashFlow +
          financingActivitiesCashFlow,
        previousSum: 0,
      },
    ];
  }

  render(): React.ReactNode {
    const waterFlowBarChartData = this.waterFlowBarChartData();
    return (
      <WaterFlowBarChart
        data={waterFlowBarChartData}
        positiveColor="#FF9EAA"
        negativeColor="#A1C2F1"
      />
    );
  }
}
