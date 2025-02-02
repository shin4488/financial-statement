import React from 'react';
import {
  BarChart,
  Bar,
  Cell,
  XAxis,
  Tooltip,
  LabelList,
  ResponsiveContainer,
} from 'recharts';
import {
  tooltipStyle,
  barChartWidth,
  barChartHeight,
} from '@/constants/values';
import { WaterFlowBarChartProps } from './props';

export default class WaterFlowBarChart extends React.Component<WaterFlowBarChartProps> {
  render(): React.ReactNode {
    return (
      <ResponsiveContainer
        className="bar-container"
        width={barChartWidth}
        height={barChartHeight}
      >
        <BarChart data={this.props.data}>
          <XAxis dataKey="name" />
          <Tooltip
            cursor={false}
            wrapperStyle={tooltipStyle}
            content={(props) => {
              const payload = props.payload;
              if (
                !props.active ||
                payload === undefined ||
                payload.length === 0
              ) {
                return;
              }

              // ペイロードの2要素目が色付き部分のデータ（1要素目は透明部分のデータ）
              return (
                <div>{`${props.label}: ${payload[1].value?.toLocaleString()}${
                  this.props.unit
                }`}</div>
              );
            }}
          />
          <Bar dataKey="previousSum" stackId="a" fill="transparent" />
          <Bar dataKey="value" stackId="a">
            <LabelList
              dataKey="value"
              position="top"
              formatter={(value: number) => value.toLocaleString()}
            />
            {this.props.data.map((dataElement, index) => (
              <Cell
                key={index}
                fill={
                  dataElement.value < 0
                    ? this.props.negativeColor
                    : this.props.positiveColor
                }
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    );
  }
}
