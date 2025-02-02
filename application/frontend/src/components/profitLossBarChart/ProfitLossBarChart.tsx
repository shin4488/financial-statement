import React from 'react';
import { stackLabelListFillColor } from '@/constants/values';
import { Bar, LabelList } from 'recharts';
import { ProfitLossBarChartProps } from './props';
import { ProfitLossAmountKeyLabel, ProfitLossChart } from './chartData';
import FinancialStatementBarChart from '@/components/financialStatementBarChart/FinancialStatementBarChart';
import ChartAlternative from '@/components/chartAlternative/ChartAlternative';

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

  // TODO:未対応の損益計算書のフォーマットに対応する
  hasInvalidData(): boolean {
    const amount = this.props.amount;
    const netSales = amount.netSales;
    const debit =
      amount.originalCost +
      amount.sellingGeneralExpense +
      amount.operatingIncome;
    return (
      // 貸借に1割以上差異があったら表示できないデータとする
      netSales === 0 || !(netSales * 0.9 <= debit && debit <= netSales * 1.1)
    );
  }

  render(): React.ReactNode {
    if (this.hasInvalidData()) {
      return (
        <ChartAlternative>
          損益計算書: データがない、または表示対応していないデータです。
        </ChartAlternative>
      );
    }

    const costSalesCharData = this.costSalesCharData();
    const hasLoss = costSalesCharData[1].operatingLossAmount > 0;

    return (
      <FinancialStatementBarChart
        data={costSalesCharData}
        tooltipFormatter={(value, name) => {
          const dataKey = name as keyof ProfitLossAmountKeyLabel;
          return [
            dataKey === 'operatingLossAmount'
              ? `-${value.toLocaleString()}円`
              : `${value.toLocaleString()}円`,
            // Barコンポーネントに渡すdataKeyはAmountのキーである前提
            `${dataKeyJapaneseHash[dataKey]}`,
          ];
        }}
      >
        {/* 借方 */}
        <Bar dataKey="originalCostAmount" stackId="a" fill="#FEBBCC">
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
        <Bar dataKey="sellingGeneralExpenseAmount" stackId="a" fill="#E48586">
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
        <Bar dataKey="netSalesAmount" stackId="a" fill="#A1C2F1">
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
        {hasLoss ? (
          <Bar dataKey="operatingLossAmount" stackId="a" fill="#F7C04A">
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
          <Bar dataKey="operatingIncomeAmount" stackId="a" fill="#8EC3B0">
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
        )}
      </FinancialStatementBarChart>
    );
  }
}
