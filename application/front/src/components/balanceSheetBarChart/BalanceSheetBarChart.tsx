import React from 'react';
import { Bar, BarChart, LabelList, YAxis } from 'recharts';
import { BalanceSheetBarChartProps } from './props';
import { stackLabelListFillColor } from '@/constants/tooltip';

type BalanceSheetChart = [
  {
    currentAsset: number;
    propertyPlantAndEquipment: number;
    intangibleAsset: number;
    investmentAndOtherAsset: number;
  },
  {
    currentLiability: number;
    noncurrentLiability: number;
    netAsset?: number;
  },
  // 債務超過の場合のみ3つ目の棒グラフを表示
  {
    blanckForInsolvency: number;
    netAsset: number;
  }?,
];

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
      },
      {
        currentLiability: this.props.currentLiability,
        noncurrentLiability: this.props.noncurrentLiability,
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
        // この場合純資産の数値はマイナスとなる
        blanckForInsolvency:
          this.props.currentLiability +
          this.props.noncurrentLiability +
          netAsset,
        netAsset: -netAsset,
      });
    } else {
      balanceSheetCharData[1].netAsset = netAsset;
    }

    return (
      <BarChart width={500} height={400} data={balanceSheetCharData}>
        <YAxis reversed hide />

        {/* 借方 */}
        <Bar dataKey="currentAsset" stackId="a" fill="#FEBBCC">
          <LabelList
            dataKey="currentAsset"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `流動資産: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="propertyPlantAndEquipment" stackId="a" fill="#E48586">
          <LabelList
            dataKey="propertyPlantAndEquipment"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `有形固定資産: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="intangibleAsset" stackId="a" fill="#FCBAAD">
          <LabelList
            dataKey="intangibleAsset"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `無形固定資産: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="investmentAndOtherAsset" stackId="a" fill="#C51605">
          <LabelList
            dataKey="investmentAndOtherAsset"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `投資その他の資産: ${String(value)}`}
          />
        </Bar>

        {/* 貸方 */}
        <Bar dataKey="currentLiability" stackId="a" fill="#5B9A8B">
          <LabelList
            dataKey="currentLiability"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `流動負債: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="noncurrentLiability" stackId="a" fill="#445069">
          <LabelList
            dataKey="noncurrentLiability"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) => `固定負債: ${String(value)}`}
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
            dataKey="netAsset"
            fill={stackLabelListFillColor}
            position="center"
            formatter={(value: unknown) =>
              `純資産: ${isInsolvency ? -Number(value) : value}`
            }
          />
        </Bar>
      </BarChart>
    );
  }
}
