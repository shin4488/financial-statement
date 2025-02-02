import React from 'react';
import { FinancialStatementBarChartProps } from './props';
import { BarChart, ResponsiveContainer, Tooltip, YAxis } from 'recharts';
import {
  barChartHeight,
  barChartWidth,
  tooltipStyle,
} from '@/constants/values';

export default class FinancialStatementBarChart<
  T extends unknown[] | undefined,
> extends React.Component<FinancialStatementBarChartProps<T>> {
  render(): React.ReactNode {
    return (
      <ResponsiveContainer
        className="bar-container"
        width={barChartWidth}
        height={barChartHeight}
      >
        <BarChart data={this.props.data}>
          <YAxis reversed hide domain={[0, 'dataMax']} />
          <Tooltip
            cursor={false}
            wrapperStyle={{
              backgroundColor: tooltipStyle.backgroundColor,
              textAlign: 'left',
            }}
            // 配列のインデックス数値が表示されてしまうため、labelはブランクとする
            labelFormatter={() => ''}
            formatter={this.props.tooltipFormatter}
          />
          {/* 具体的なBarの内容は呼び出し側で設定する */}
          {this.props.children}
        </BarChart>
      </ResponsiveContainer>
    );
  }
}
