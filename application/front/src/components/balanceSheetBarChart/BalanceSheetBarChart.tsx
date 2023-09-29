import React from 'react';
import { Bar, LabelList } from 'recharts';
import { stackLabelListFillColor } from '@/constants/values';
import { BalanceSheetBarChartProps } from './props';
import { BalanceSheetAmountKeyLabel, BalanceSheetChart } from './chartData';
import FinancialStatementBarChart from '@/components/financialStatementBarChart/FinancialStatementBarChart';
import ChartAlternative from '@/components/chartAlternative/ChartAlternative';

const dataKeyJapaneseHash: BalanceSheetAmountKeyLabel = {
  currentAssetAmount: '流動資産',
  propertyPlantAndEquipmentAmount: '有形固定資産',
  intangibleAssetAmount: '無形固定資産',
  investmentAndOtherAssetAmount: '投資その他資産',
  currentLiabilityAmount: '流動負債',
  noncurrentLiabilityAmount: '固定負債',
  netAssetAmount: '純資産',
};

export default class BalanceSheetBarCahrt extends React.Component<BalanceSheetBarChartProps> {
  /**
   * 債務超過の状態である
   * @returns
   */
  isInsolvency(): boolean {
    return this.props.amount.netAsset < 0;
  }

  balanceSheetCharData(): BalanceSheetChart {
    const amount = this.props.amount;
    const ratio = this.props.ratio;
    return [
      {
        currentAssetAmount: amount.currentAsset,
        propertyPlantAndEquipmentAmount: amount.propertyPlantAndEquipment,
        intangibleAssetAmount: amount.intangibleAsset,
        investmentAndOtherAssetAmount: amount.investmentAndOtherAsset,
        currentAssetRatio: ratio.currentAsset,
        propertyPlantAndEquipmentRatio: ratio.propertyPlantAndEquipment,
        intangibleAssetRatio: ratio.intangibleAsset,
        investmentAndOtherAssetRatio: ratio.investmentAndOtherAsset,
      },
      {
        currentLiabilityAmount: amount.currentLiability,
        noncurrentLiabilityAmount: amount.noncurrentLiability,
        currentLiabilityRatio: ratio.currentLiability,
        noncurrentLiabilityRatio: ratio.noncurrentLiability,
      },
    ];
  }

  // TODO:未対応の貸借対照書のフォーマットに対応する
  hasInvalidData(): boolean {
    const amount = this.props.amount;

    const debit =
      amount.currentAsset +
      amount.propertyPlantAndEquipment +
      amount.intangibleAsset +
      amount.investmentAndOtherAsset;
    const credit =
      amount.currentLiability + amount.noncurrentLiability + amount.netAsset;
    // 貸借に1割以上差異があったら表示できないデータとする
    return !(debit * 0.9 <= credit && credit <= debit * 1.1);
  }

  render(): React.ReactNode {
    if (this.hasInvalidData()) {
      return (
        <ChartAlternative>
          貸借対照表: データがない、または表示対応していないデータです。
        </ChartAlternative>
      );
    }

    const balanceSheetCharData = this.balanceSheetCharData();
    const isInsolvency = this.isInsolvency();
    const amount = this.props.amount;
    const ratio = this.props.ratio;
    const netAsset = amount.netAsset;
    // 債務超過の場合は3本目のグラフに純資産を表示する
    if (isInsolvency) {
      balanceSheetCharData.push({
        // この場合純資産の数値はマイナスとなるため、ブランク分の数値は「負債 - 純資産（債務超過分）」となる
        blanckForInsolvencyAmount:
          amount.currentLiability + amount.noncurrentLiability + netAsset,
        // マイナス数値をChartに表示すると逆方法に表示されてしまうため、Chartに渡す数値はプラスにする
        netAssetAmount: -netAsset,
        netAssetRatio: -ratio.netAsset,
      });
    } else {
      balanceSheetCharData[1].netAssetAmount = netAsset;
      balanceSheetCharData[1].netAssetRatio = ratio.netAsset;
    }

    return (
      <FinancialStatementBarChart
        data={balanceSheetCharData}
        tooltipFormatter={(value, name) => {
          const balanceSheetAmountKey =
            name as keyof BalanceSheetAmountKeyLabel;
          return [
            this.isInsolvency() && balanceSheetAmountKey === 'netAssetAmount'
              ? `-${value.toLocaleString()}円`
              : `${value.toLocaleString()}円`,
            // Barコンポーネントに渡すdataKeyはAmountのキーである前提
            `${dataKeyJapaneseHash[balanceSheetAmountKey]}`,
          ];
        }}
      >
        {/* 借方 */}
        <Bar dataKey="currentAssetAmount" stackId="a" fill="#A1C2F1">
          <LabelList
            dataKey="currentAssetRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.currentAssetAmount}: ${value}%`
            }
          />
        </Bar>
        <Bar
          dataKey="propertyPlantAndEquipmentAmount"
          stackId="a"
          fill="#5A96E3"
        >
          <LabelList
            dataKey="propertyPlantAndEquipmentRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.propertyPlantAndEquipmentAmount}: ${value}%`
            }
          />
        </Bar>
        <Bar dataKey="intangibleAssetAmount" stackId="a" fill="#7286D3">
          <LabelList
            dataKey="intangibleAssetRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.intangibleAssetAmount}: ${value}%`
            }
          />
        </Bar>
        <Bar dataKey="investmentAndOtherAssetAmount" stackId="a" fill="#576CBC">
          <LabelList
            dataKey="investmentAndOtherAssetRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.investmentAndOtherAssetAmount}: ${value}%`
            }
          />
        </Bar>

        {/* 貸方 */}
        <Bar dataKey="currentLiabilityAmount" stackId="a" fill="#FEBBCC">
          <LabelList
            dataKey="currentLiabilityRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.currentLiabilityAmount}: ${value}%`
            }
          />
        </Bar>
        <Bar dataKey="noncurrentLiabilityAmount" stackId="a" fill="#E48586">
          <LabelList
            dataKey="noncurrentLiabilityRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.noncurrentLiabilityAmount}: ${value}%`
            }
          />
        </Bar>
        {isInsolvency ? (
          // 債務超過の場合のみ3つ目の棒グラフを表示、債務超過の分だけ資産（借方）には空白スペースを表示
          <Bar
            dataKey="blanckForInsolvencyAmount"
            stackId="a"
            fill="transparent"
          />
        ) : (
          <></>
        )}
        <Bar dataKey="netAssetAmount" stackId="a" fill="#8EC3B0">
          <LabelList
            dataKey="netAssetRatio"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: number) =>
              `${dataKeyJapaneseHash.netAssetAmount}: ${
                isInsolvency ? -Number(value) : value
              }%`
            }
          />
        </Bar>
      </FinancialStatementBarChart>
    );
  }
}
