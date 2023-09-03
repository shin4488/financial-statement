import React from 'react';
import {
  Bar,
  BarChart,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  YAxis,
} from 'recharts';
import {
  stackLabelListFillColor,
  barChartWidth,
  barChartHeight,
  tooltipStyle,
} from '@/constants/values';
import { BalanceSheetBarChartProps } from './props';
import { BalanceSheetAmountKeyLabel, BalanceSheetChart } from './chartData';

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

  render(): React.ReactNode {
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
      <ResponsiveContainer
        className="bar-container"
        width={barChartWidth}
        height={barChartHeight}
      >
        <BarChart data={balanceSheetCharData}>
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
              return [
                this.isInsolvency()
                  ? `-${value.toLocaleString()}`
                  : value.toLocaleString(),
                // Barコンポーネントに渡すdataKeyはAmountのキーである前提
                `${
                  dataKeyJapaneseHash[name as keyof BalanceSheetAmountKeyLabel]
                }`,
              ];
            }}
          />

          {/* 借方 */}
          <Bar dataKey="currentAssetAmount" stackId="a" fill="#FEBBCC">
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
            fill="#E48586"
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
          <Bar dataKey="intangibleAssetAmount" stackId="a" fill="#FCBAAD">
            <LabelList
              dataKey="intangibleAssetRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.intangibleAssetAmount}: ${value}%`
              }
            />
          </Bar>
          <Bar
            dataKey="investmentAndOtherAssetAmount"
            stackId="a"
            fill="#C51605"
          >
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
          <Bar dataKey="currentLiabilityAmount" stackId="a" fill="#5B9A8B">
            <LabelList
              dataKey="currentLiabilityRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.currentLiabilityAmount}: ${value}%`
              }
            />
          </Bar>
          <Bar dataKey="noncurrentLiabilityAmount" stackId="a" fill="#445069">
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
          <Bar dataKey="netAssetAmount" stackId="a" fill="#252B48">
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
        </BarChart>
      </ResponsiveContainer>
    );
  }
}
