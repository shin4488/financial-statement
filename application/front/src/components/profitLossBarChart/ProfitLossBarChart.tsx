import React from 'react';
import { stackLabelListFillColor } from '@/constants/tooltip';
import { BarChart, Bar, LabelList } from 'recharts';
import { ProfitLossBarChartProps } from './props';

type ProfitLossChart = [
  {
    originalCost: number;
    sellingGeneralExpense: number;
    operatingIncome: number;
  },
  {
    netSales: number;
    operatingLoss: number;
  },
];

export default class ProfitLossBarChart extends React.Component<ProfitLossBarChartProps> {
  costSalesCharData(): ProfitLossChart {
    return [
      {
        originalCost: this.props.originalCost,
        sellingGeneralExpense: this.props.sellingGeneralExpense,
        operatingIncome: Math.max(0, this.props.operatingIncome),
      },
      // マイナス数値を棒グラフに表示すると上から下へ向かって表示されてしまうため、下から上へグラフが出るようにプラス数値へ変える
      {
        netSales: this.props.netSales,
        operatingLoss: -Math.min(0, this.props.operatingIncome),
      },
    ];
  }

  render(): React.ReactNode {
    const costSalesCharData = this.costSalesCharData();
    const hasLoss = costSalesCharData[1].operatingLoss > 0;
    const profitLossComponent = hasLoss ? (
      <Bar dataKey="operatingLoss" stackId="a" fill="#5B9A8B">
        <LabelList
          dataKey="operatingLoss"
          formatter={(value: unknown) => `営業損失: ${String(value)}`}
          position="center"
          fill={stackLabelListFillColor}
        />
      </Bar>
    ) : (
      <Bar dataKey="operatingIncome" stackId="a" fill="#3D246C">
        <LabelList
          dataKey="operatingIncome"
          formatter={(value: unknown) => `営業利益: ${String(value)}`}
          position="center"
          fill={stackLabelListFillColor}
        />
      </Bar>
    );

    return (
      <BarChart width={500} height={400} data={costSalesCharData}>
        {profitLossComponent}
        <Bar dataKey="netSales" stackId="a" fill="#F94C10">
          <LabelList
            dataKey="netSales"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="sellingGeneralExpense" stackId="a" fill="#5C4B99">
          <LabelList
            dataKey="sellingGeneralExpense"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `販売一般管理費: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="originalCost" stackId="a" fill="#9F91CC">
          <LabelList
            dataKey="originalCost"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上原価: ${String(value)}`}
          />
        </Bar>
      </BarChart>
    );
  }
}
