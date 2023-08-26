import React from 'react';
import { stackLabelListFillColor } from '@/constants/tooltip';
import { BarChart, Bar, LabelList } from 'recharts';
import { ProfitLossBarChartProps } from './props';

type ProfitLossChart = [
  {
    costOfSales: number;
    sellingAdministrativeExpense: number;
    operatingIncome: number;
  },
  {
    sales: number;
    operatingLoss: number;
  },
];

export default class ProfitLossBarChart extends React.Component<ProfitLossBarChartProps> {
  costSalesCharData(): ProfitLossChart {
    return [
      {
        costOfSales: this.props.costOfSales,
        sellingAdministrativeExpense: this.props.sellingAdministrativeExpense,
        operatingIncome: Math.max(0, this.props.operatingIncome),
      },
      // マイナス数値を棒グラフに表示すると上から下へ向かって表示されてしまうため、下から上へグラフが出るようにプラス数値へ変える
      {
        sales: this.props.sales,
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
        <Bar dataKey="sales" stackId="a" fill="#F94C10">
          <LabelList
            dataKey="sales"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="sellingAdministrativeExpense" stackId="a" fill="#5C4B99">
          <LabelList
            dataKey="sellingAdministrativeExpense"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `販売一般管理費: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="costOfSales" stackId="a" fill="#9F91CC">
          <LabelList
            dataKey="costOfSales"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上原価: ${String(value)}`}
          />
        </Bar>
      </BarChart>
    );
  }
}
