import React from 'react';
import { BarChart, Bar, LabelList } from 'recharts';
import { ProfitLossBarChartProps } from './props';

type ProfitLossChart = [
  {
    costOfSales: number;
    sellingAdministrativeExpense: number;
    operatingProfit: number;
  },
  {
    sales: number;
    operatingLoss: number;
  },
];

export default class ProfitLossBarChart extends React.Component<ProfitLossBarChartProps> {
  costSalesCharData(): ProfitLossChart {
    const sales = this.props.sales;
    const costOfSales = this.props.costOfSales;
    const sellingAdministrativeExpense =
      this.props.sellingAdministrativeExpense;
    const operatingProfit =
      sales - (costOfSales + sellingAdministrativeExpense);

    return [
      {
        costOfSales: costOfSales,
        sellingAdministrativeExpense: sellingAdministrativeExpense,
        operatingProfit: Math.max(0, operatingProfit),
      },
      // マイナス数値を棒グラフに表示すると上から下へ向かって表示されてしまうため、下から上へグラフが出るようにプラス数値へ変える
      { sales: sales, operatingLoss: -Math.min(0, operatingProfit) },
    ];
  }

  render(): React.ReactNode {
    const costSalesCharData = this.costSalesCharData();
    const hasLoss = costSalesCharData[1].operatingLoss > 0;
    const labelListFillColor = '#FFF';
    const profitLossComponent = hasLoss ? (
      <Bar dataKey="operatingLoss" stackId="a" fill="#5B9A8B">
        <LabelList
          dataKey="operatingLoss"
          formatter={(value: unknown) => `営業損失: ${String(value)}`}
          position="center"
          fill={labelListFillColor}
        />
      </Bar>
    ) : (
      <Bar dataKey="operatingProfit" stackId="a" fill="#3D246C">
        <LabelList
          dataKey="operatingProfit"
          formatter={(value: unknown) => `営業利益: ${String(value)}`}
          position="center"
          fill={labelListFillColor}
        />
      </Bar>
    );

    return (
      <BarChart width={500} height={400} data={costSalesCharData}>
        {profitLossComponent}
        <Bar dataKey="sales" stackId="a" fill="#F94C10">
          <LabelList
            dataKey="sales"
            fill={labelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="sellingAdministrativeExpense" stackId="a" fill="#5C4B99">
          <LabelList
            dataKey="sellingAdministrativeExpense"
            fill={labelListFillColor}
            position="center"
            formatter={(value: unknown) => `販売一般管理費: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="costOfSales" stackId="a" fill="#9F91CC">
          <LabelList
            dataKey="costOfSales"
            fill={labelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上原価: ${String(value)}`}
          />
        </Bar>
      </BarChart>
    );
  }
}
