import React from 'react';
import ProfitLossBarChart from '@/components/profitLossBarChart/ProfitLossBarChart';
import { ProfitLossBarChartProps } from '@/components/profitLossBarChart/props';
import CashFlowBarChart from '@/components/cashFlowBarChart/CashFlowBarChart';
import { CashFlowBarChartProps } from '@/components/cashFlowBarChart/props';

interface ChartsState {
  profitLossData: ProfitLossBarChartProps[];
  cashFlowData: CashFlowBarChartProps[];
}

export default class DevCharts extends React.Component<unknown, ChartsState> {
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
          <CashFlowBarChart
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
