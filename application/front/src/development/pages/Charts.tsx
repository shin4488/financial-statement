import React from 'react';
import { BarChart, Bar, Cell, XAxis, Tooltip, LabelList } from 'recharts';

interface ProfitLossBarChartProps {
  sales: number;
  costOfSales: number;
  sellingAdministrativeExpense: number;
}

type ProfitLossChart = [
  {
    costOfSales: number;
    sellingAdministrativeExpense: number;
    operatingProfit: number;
  },
  {
    sales: number;
    operatingLoss: number;
  },
];

const tooltipStyle = {
  backgroundColor: '#F6F4EB',
  opacity: '0.8',
  padding: '10px',
};

class ProfitLossBarChart extends React.Component<ProfitLossBarChartProps> {
  costSalesCharData(): ProfitLossChart {
    const sales = this.props.sales;
    const costOfSales = this.props.costOfSales;
    const sellingAdministrativeExpense =
      this.props.sellingAdministrativeExpense;
    const operatingProfit =
      sales - (costOfSales + sellingAdministrativeExpense);

    return [
      {
        costOfSales: costOfSales,
        sellingAdministrativeExpense: sellingAdministrativeExpense,
        operatingProfit: Math.max(0, operatingProfit),
      },
      // マイナス数値を棒グラフに表示すると上から下へ向かって表示されてしまうため、下から上へグラフが出るようにプラス数値へ変える
      { sales: sales, operatingLoss: -Math.min(0, operatingProfit) },
    ];
  }

  render(): React.ReactNode {
    const costSalesCharData = this.costSalesCharData();
    const hasLoss = costSalesCharData[1].operatingLoss > 0;
    const labelListFillColor = '#FFF';
    const profitLossComponent = hasLoss ? (
      <Bar dataKey="operatingLoss" stackId="a" fill="#5B9A8B">
        <LabelList
          dataKey="operatingLoss"
          formatter={(value: unknown) => `営業損失: ${String(value)}`}
          position="center"
          fill={labelListFillColor}
        />
      </Bar>
    ) : (
      <Bar dataKey="operatingProfit" stackId="a" fill="#3D246C">
        <LabelList
          dataKey="operatingProfit"
          formatter={(value: unknown) => `営業利益: ${String(value)}`}
          position="center"
          fill={labelListFillColor}
        />
      </Bar>
    );
    return (
      <BarChart width={500} height={400} data={costSalesCharData}>
        {profitLossComponent}
        <Bar dataKey="sales" stackId="a" fill="#F94C10">
          <LabelList
            dataKey="sales"
            fill={labelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="sellingAdministrativeExpense" stackId="a" fill="#5C4B99">
          <LabelList
            dataKey="sellingAdministrativeExpense"
            fill={labelListFillColor}
            position="center"
            formatter={(value: unknown) => `販売一般管理費: ${String(value)}`}
          />
        </Bar>
        <Bar dataKey="costOfSales" stackId="a" fill="#9F91CC">
          <LabelList
            dataKey="costOfSales"
            fill={labelListFillColor}
            position="center"
            formatter={(value: unknown) => `売上原価: ${String(value)}`}
          />
        </Bar>
      </BarChart>
    );
  }
}

interface WaterFlowBarChartDataElement {
  name: string;
  cash: number;
  sum: number;
}

interface WaterFlowBarChartProps {
  openingBalance: number;
  operatingActivitiesCashFlow: number;
  investingActivitiesCashFlow: number;
  financingActivitiesCashFlow: number;
}

class WaterFlowBarChart extends React.Component<WaterFlowBarChartProps> {
  waterFlowBarChartData(): WaterFlowBarChartDataElement[] {
    const openingBalance = this.props.openingBalance;
    const operatingActivitiesCashFlow = this.props.operatingActivitiesCashFlow;
    const investingActivitiesCashFlow = this.props.investingActivitiesCashFlow;
    const financingActivitiesCashFlow = this.props.financingActivitiesCashFlow;
    return [
      { name: '期首残高', cash: openingBalance, sum: 0 },
      {
        name: '営業CF',
        cash: operatingActivitiesCashFlow,
        sum: openingBalance,
      },
      {
        name: '投資CF',
        cash: investingActivitiesCashFlow,
        sum: openingBalance + operatingActivitiesCashFlow,
      },
      {
        name: '財務CF',
        cash: financingActivitiesCashFlow,
        sum:
          openingBalance +
          operatingActivitiesCashFlow +
          investingActivitiesCashFlow,
      },
      {
        name: '期末残高',
        cash:
          openingBalance +
          operatingActivitiesCashFlow +
          investingActivitiesCashFlow +
          financingActivitiesCashFlow,
        sum: 0,
      },
    ];
  }

  render(): React.ReactNode {
    const waterFlowBarChartData = this.waterFlowBarChartData();
    return (
      <BarChart width={500} height={400} data={waterFlowBarChartData}>
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
        <Bar dataKey="sum" stackId="a" fill="transparent" />
        <Bar dataKey="cash" stackId="a">
          <LabelList dataKey="cash" position="top" />
          {waterFlowBarChartData.map((cashFlow, index) =>
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
  profitLossData: ProfitLossBarChartProps[];
  cashFlowData: WaterFlowBarChartProps[];
}

export default class Charts extends React.Component<unknown, ChartsState> {
  state: Readonly<ChartsState> = {
    profitLossData: [
      {
        sales: 10000,
        costOfSales: 6000,
        sellingAdministrativeExpense: 2000,
      },
      {
        sales: 10000,
        costOfSales: 6000,
        sellingAdministrativeExpense: 5000,
      },
      {
        sales: 10000,
        costOfSales: 6000,
        sellingAdministrativeExpense: 4000,
      },
      {
        sales: 10000,
        costOfSales: 6000,
        sellingAdministrativeExpense: 3999,
      },
    ],
    cashFlowData: [
      {
        openingBalance: 400,
        operatingActivitiesCashFlow: 700,
        investingActivitiesCashFlow: -300,
        financingActivitiesCashFlow: 200,
      },
      {
        openingBalance: 100000,
        operatingActivitiesCashFlow: -200000,
        investingActivitiesCashFlow: -300,
        financingActivitiesCashFlow: 10000,
      },
    ],
  };

  render(): React.ReactNode {
    return (
      <>
        {this.state.profitLossData.map((profitLoss, index) => (
          <ProfitLossBarChart
            key={index}
            sales={profitLoss.sales}
            costOfSales={profitLoss.costOfSales}
            sellingAdministrativeExpense={
              profitLoss.sellingAdministrativeExpense
            }
          />
        ))}
        {this.state.cashFlowData.map((cashFlow, index) => (
          <WaterFlowBarChart
            key={index}
            openingBalance={cashFlow.openingBalance}
            operatingActivitiesCashFlow={cashFlow.operatingActivitiesCashFlow}
            investingActivitiesCashFlow={cashFlow.investingActivitiesCashFlow}
            financingActivitiesCashFlow={cashFlow.financingActivitiesCashFlow}
          />
        ))}
      </>
    );
  }
}
