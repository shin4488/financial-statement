import React from 'react';
import {
  stackLabelListFillColor,
  barChartWidth,
  barChartHeight,
  tooltipStyle,
} from '@/constants/values';
import {
  BarChart,
  Bar,
  LabelList,
  YAxis,
  ResponsiveContainer,
  Tooltip,
} from 'recharts';
import { ProfitLossBarChartProps } from './props';
import { ProfitLossAmountKeyLabel, ProfitLossChart } from './chartData';

const dataKeyJapaneseHash: ProfitLossAmountKeyLabel = {
  originalCostAmount: '売上原価',
  sellingGeneralExpenseAmount: '販管費',
  operatingIncomeAmount: '営業利益',
  netSalesAmount: '売上',
  operatingLossAmount: '営業損失',
};

export default class ProfitLossBarChart extends React.Component<ProfitLossBarChartProps> {
  costSalesCharData(): ProfitLossChart {
    const amount = this.props.amount;
    const ratio = this.props.ratio;
    return [
      {
        originalCostAmount: amount.originalCost,
        sellingGeneralExpenseAmount: amount.sellingGeneralExpense,
        operatingIncomeAmount: Math.max(0, amount.operatingIncome),
        originalCostRatio: ratio.originalCost,
        sellingGeneralExpenseRatio: ratio.sellingGeneralExpense,
        operatingIncomeRatio: Math.max(0, ratio.operatingIncome),
      },
      {
        netSalesAmount: amount.netSales,
        // マイナス数値を棒グラフに表示すると上から下へ向かって表示されてしまうため、下から上へグラフが出るようにプラス数値へ変える
        operatingLossAmount: -Math.min(0, amount.operatingIncome),
        netSalesRatio: ratio.netSales,
        operatingLossRatio: -Math.min(0, ratio.operatingIncome),
      },
    ];
  }

  render(): React.ReactNode {
    const costSalesCharData = this.costSalesCharData();
    const hasLoss = costSalesCharData[1].operatingLossAmount > 0;
    const profitLossComponent = hasLoss ? (
      <Bar dataKey="operatingLossAmount" stackId="a" fill="#5B9A8B">
        <LabelList
          dataKey="operatingLossRatio"
          formatter={(value: number) =>
            `${
              dataKeyJapaneseHash.operatingLossAmount
            }: -${value.toLocaleString()}%`
          }
          position="center"
          fill={stackLabelListFillColor}
        />
      </Bar>
    ) : (
      <Bar dataKey="operatingIncomeAmount" stackId="a" fill="#3D246C">
        <LabelList
          dataKey="operatingIncomeRatio"
          formatter={(value: number) =>
            `${
              dataKeyJapaneseHash.operatingIncomeAmount
            }: ${value.toLocaleString()}%`
          }
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
          <Tooltip
            cursor={false}
            wrapperStyle={{
              backgroundColor: tooltipStyle.backgroundColor,
              textAlign: 'left',
            }}
            // 配列のインデックス数値が表示されてしまうため、labelはブランクとする
            labelFormatter={() => ''}
            formatter={(value, name) => {
              const dataKey = name as keyof ProfitLossAmountKeyLabel;
              return [
                dataKey === 'operatingLossAmount'
                  ? `-${value.toLocaleString()}`
                  : value.toLocaleString(),
                // Barコンポーネントに渡すdataKeyはAmountのキーである前提
                `${dataKeyJapaneseHash[dataKey]}`,
              ];
            }}
          />

          {/* 借方 */}
          <Bar dataKey="originalCostAmount" stackId="a" fill="#9F91CC">
            <LabelList
              dataKey="originalCostRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${
                  dataKeyJapaneseHash.originalCostAmount
                }: ${value.toLocaleString()}%`
              }
            />
          </Bar>
          <Bar dataKey="sellingGeneralExpenseAmount" stackId="a" fill="#5C4B99">
            <LabelList
              dataKey="sellingGeneralExpenseRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${
                  dataKeyJapaneseHash.sellingGeneralExpenseAmount
                }: ${value.toLocaleString()}%`
              }
            />
          </Bar>

          {/* 貸方 */}
          <Bar dataKey="netSalesAmount" stackId="a" fill="#F94C10">
            <LabelList
              dataKey="netSalesRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${
                  dataKeyJapaneseHash.netSalesAmount
                }: ${value.toLocaleString()}%`
              }
            />
          </Bar>
          {/* 営業利益/営業損失はどちらの場合でも積み上げの一番下に表示する */}
          {profitLossComponent}
        </BarChart>
      </ResponsiveContainer>
    );
  }
}
