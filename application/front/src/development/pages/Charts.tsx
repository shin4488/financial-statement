import React from 'react';
import { BarChart, Bar, Cell, XAxis, Tooltip } from 'recharts';

interface CashFlow {
  name: string;
  cash: number;
  sum: number;
}

interface WaterFlowBarChartProps {
  cashFlowData: CashFlow[];
}

class WaterFlowBarChart extends React.Component<WaterFlowBarChartProps> {
  render(): React.ReactNode {
    return (
      <BarChart width={500} height={400} data={this.props.cashFlowData}>
        <XAxis dataKey="name" />
        <Tooltip
          cursor={false}
          wrapperStyle={{ backgroundColor: '#F6F4EB', opacity: '0.8' }}
          content={({ active, payload, label }) => {
            if (!active || payload === undefined || payload.length === 0) {
              return;
            }

            return <div>{`${label}: ${payload[0].value}`}</div>;
          }}
        />
        <Bar dataKey="sum" stackId="a" fill="transparent" />
        <Bar dataKey="cash" stackId="a" fill="#82ca9d">
          {this.props.cashFlowData.map((cashFlow: CashFlow, index) =>
            cashFlow.cash < 0 ? (
              <Cell key={index} fill="#FF9EAA" />
            ) : (
              <Cell key={index} fill="#A1C2F1" />
            ),
          )}
        </Bar>
      </BarChart>
    );
  }
}

interface ChartsState {
  cashFlowData: CashFlow[];
}

export default class Charts extends React.Component<unknown, ChartsState> {
  state: Readonly<ChartsState> = {
    cashFlowData: [
      { name: '期首残高', cash: 400, sum: 0 },
      { name: '営業CF', cash: 700, sum: 400 },
      { name: '投資CF', cash: -300, sum: 1100 },
      { name: '財務CF', cash: 200, sum: 800 },
      { name: '期末残高', cash: 1000, sum: 0 },
    ],
  };

  render(): React.ReactNode {
    return (
      <>
        <WaterFlowBarChart cashFlowData={this.state.cashFlowData} />
      </>
    );
  }
}
