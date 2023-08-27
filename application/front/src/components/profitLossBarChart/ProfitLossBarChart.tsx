import React from 'react';
import {
  stackLabelListFillColor,
  barChartWidth,
  barChartHeight,
} from '@/constants/chart';
import { BarChart, Bar, LabelList, YAxis, ResponsiveContainer } from 'recharts';
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
          formatter={(value: number) => `営業損失: ${value.toLocaleString()}`}
          position="center"
          fill={stackLabelListFillColor}
        />
      </Bar>
    ) : (
      <Bar dataKey="operatingIncome" stackId="a" fill="#3D246C">
        <LabelList
          dataKey="operatingIncome"
          formatter={(value: number) => `営業利益: ${value.toLocaleString()}`}
          position="center"
          fill={stackLabelListFillColor}
        />
      </Bar>
    );

    return (
      <ResponsiveContainer
        className="bar-container"
        width={barChartWidth}
        height={barChartHeight}
      >
        <BarChart data={costSalesCharData}>
          <YAxis reversed hide />

          {/* 借方 */}
          <Bar dataKey="originalCost" stackId="a" fill="#9F91CC">
            <LabelList
              dataKey="originalCost"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `売上原価: ${value.toLocaleString()}`
              }
            />
          </Bar>
          <Bar dataKey="sellingGeneralExpense" stackId="a" fill="#5C4B99">
            <LabelList
              dataKey="sellingGeneralExpense"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `販売一般管理費: ${value.toLocaleString()}`
              }
            />
          </Bar>

          {/* 貸方 */}
          <Bar dataKey="netSales" stackId="a" fill="#F94C10">
            <LabelList
              dataKey="netSales"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) => `売上: ${value.toLocaleString()}`}
            />
          </Bar>
          {/* 営業利益/営業損失はどちらの場合でも積み上げの一番下に表示する */}
          {profitLossComponent}
        </BarChart>
      </ResponsiveContainer>
    );
  }
}
