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
  currentAsset: '流動資産',
  propertyPlantAndEquipment: '有形固定資産',
  intangibleAsset: '無形固定資産',
  investmentAndOtherAsset: '投資その他資産',
  currentLiability: '流動負債',
  noncurrentLiability: '固定負債',
  netAsset: '純資産',
};

export default class BalanceSheetBarCahrt extends React.Component<BalanceSheetBarChartProps> {
  /**
   * 債務超過の状態である
   * @returns
   */
  isInsolvency(): boolean {
    return this.props.netAsset < 0;
  }

  balanceSheetCharData(): BalanceSheetChart {
    return [
      {
        currentAsset: this.props.currentAsset,
        propertyPlantAndEquipment: this.props.propertyPlantAndEquipment,
        intangibleAsset: this.props.intangibleAsset,
        investmentAndOtherAsset: this.props.investmentAndOtherAsset,
        currentAssetRatio: 40,
        propertyPlantAndEquipmentRatio: 20,
        intangibleAssetRatio: 30,
        investmentAndOtherAssetRatio: 10,
      },
      {
        currentLiability: this.props.currentLiability,
        noncurrentLiability: this.props.noncurrentLiability,
        currentLiabilityRatio: 30,
        noncurrentLiabilityRatio: 20,
      },
    ];
  }

  render(): React.ReactNode {
    const balanceSheetCharData = this.balanceSheetCharData();
    const isInsolvency = this.isInsolvency();
    const netAsset = this.props.netAsset;
    // 債務超過の場合は3本目のグラフに純資産を表示する
    if (isInsolvency) {
      balanceSheetCharData.push({
        // この場合純資産の数値はマイナスとなるため、ブランク分の数値は「負債 - 純資産（債務超過分）」となる
        blanckForInsolvency:
          this.props.currentLiability +
          this.props.noncurrentLiability +
          netAsset,
        // マイナス数値をChartに表示すると逆方法に表示されてしまうため、Chartに渡す数値はプラスにする
        netAsset: -netAsset,
        netAssetRatio: 30,
      });
    } else {
      balanceSheetCharData[1].netAsset = netAsset;
      balanceSheetCharData[1].netAssetRatio = 30;
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
                value.toLocaleString(),
                // Barコンポーネントに渡すdataKeyはAmountのキーである前提
                `${
                  dataKeyJapaneseHash[name as keyof BalanceSheetAmountKeyLabel]
                }`,
              ];
            }}
          />

          {/* 借方 */}
          <Bar dataKey="currentAsset" stackId="a" fill="#FEBBCC">
            <LabelList
              dataKey="currentAssetRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.currentAsset}: ${value}%`
              }
            />
          </Bar>
          <Bar dataKey="propertyPlantAndEquipment" stackId="a" fill="#E48586">
            <LabelList
              dataKey="propertyPlantAndEquipmentRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.propertyPlantAndEquipment}: ${value}%`
              }
            />
          </Bar>
          <Bar dataKey="intangibleAsset" stackId="a" fill="#FCBAAD">
            <LabelList
              dataKey="intangibleAssetRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.intangibleAsset}: ${value}%`
              }
            />
          </Bar>
          <Bar dataKey="investmentAndOtherAsset" stackId="a" fill="#C51605">
            <LabelList
              dataKey="investmentAndOtherAssetRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.investmentAndOtherAsset}: ${value}%`
              }
            />
          </Bar>

          {/* 貸方 */}
          <Bar dataKey="currentLiability" stackId="a" fill="#5B9A8B">
            <LabelList
              dataKey="currentLiabilityRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.currentLiability}: ${value}%`
              }
            />
          </Bar>
          <Bar dataKey="noncurrentLiability" stackId="a" fill="#445069">
            <LabelList
              dataKey="noncurrentLiabilityRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.noncurrentLiability}: ${value}%`
              }
            />
          </Bar>
          {isInsolvency ? (
            // 債務超過の場合のみ3つ目の棒グラフを表示、債務超過の分だけ資産（借方）には空白スペースを表示
            <Bar dataKey="blanckForInsolvency" stackId="a" fill="transparent" />
          ) : (
            <></>
          )}
          <Bar dataKey="netAsset" stackId="a" fill="#252B48">
            <LabelList
              dataKey="netAssetRatio"
              fill={stackLabelListFillColor}
              position="center"
              formatter={(value: number) =>
                `${dataKeyJapaneseHash.netAsset}: ${
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
