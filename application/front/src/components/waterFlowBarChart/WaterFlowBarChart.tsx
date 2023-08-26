import React from 'react';
import { BarChart, Bar, Cell, XAxis, Tooltip, LabelList } from 'recharts';
import { tooltipStyle } from '@/constants/tooltip';
import { WaterFlowBarChartProps } from './props';

export default class WaterFlowBarChart extends React.Component<WaterFlowBarChartProps> {
  render(): React.ReactNode {
    return (
      <BarChart width={500} height={400} data={this.props.data}>
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
            return <div>{`${props.label}: ${payload[1].value}`}</div>;
          }}
        />
        <Bar dataKey="previousSum" stackId="a" fill="transparent" />
        <Bar dataKey="value" stackId="a">
          <LabelList dataKey="value" position="top" />
          {this.props.data.map((dataElement, index) =>
            dataElement.value < 0 ? (
              <Cell key={index} fill={this.props.positiveColor} />
            ) : (
              <Cell key={index} fill={this.props.negativeColor} />
            ),
          )}
        </Bar>
      </BarChart>
    );
  }
}
