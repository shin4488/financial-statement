import React from 'react';
import { ChartAlternativeProps } from './props';
import { barChartHeight, barChartWidth } from '@/constants/values';

export default class ChartAlternative extends React.Component<ChartAlternativeProps> {
  render(): React.ReactNode {
    return (
      <div
        style={{
          width: barChartWidth,
          height: barChartHeight,
          textAlign: 'left',
        }}
      >
        {this.props.children}
      </div>
    );
  }
}
