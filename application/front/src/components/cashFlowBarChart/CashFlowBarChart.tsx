import React from 'react';
import { CashFlowBarChartProps } from './props';
import WaterFlowBarChart from '@/components/waterFlowBarChart/WaterFlowBarChart';
import { WaterFlowBarChartElement } from '@/components/waterFlowBarChart/props';

export default class CashFlowBarChart extends React.Component<CashFlowBarChartProps> {
  waterFlowBarChartData(): WaterFlowBarChartElement[] {
    const startingCash = this.props.startingCash;
    const operatingActivitiesCashFlow = this.props.operatingActivitiesCashFlow;
    const investingActivitiesCashFlow = this.props.investingActivitiesCashFlow;
    const financingActivitiesCashFlow = this.props.financingActivitiesCashFlow;
    return [
      // sumの部分が透明となるため、sumは前の要素までの合計値とする
      { name: '期首残高', value: startingCash, previousSum: 0 },
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
        name: '期末残高',
        value: this.props.endingCash,
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
