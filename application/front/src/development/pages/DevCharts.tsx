import React from 'react';
import ProfitLossBarChart from '@/components/profitLossBarChart/ProfitLossBarChart';
import { ProfitLossBarChartProps } from '@/components/profitLossBarChart/props';
import CashFlowBarChart from '@/components/cashFlowBarChart/CashFlowBarChart';
import { CashFlowBarChartProps } from '@/components/cashFlowBarChart/props';

interface DevChartsState {
  profitLossData: ProfitLossBarChartProps[];
  cashFlowData: CashFlowBarChartProps[];
}

export default class DevCharts extends React.Component<
  unknown,
  DevChartsState
> {
  state: Readonly<DevChartsState> = {
    profitLossData: [
      {
        netSales: 10000,
        originalCost: 6000,
        sellingGeneralExpense: 2000,
        operatingIncome: 10000 - 6000 - 2000,
      },
      {
        netSales: 10000,
        originalCost: 6000,
        sellingGeneralExpense: 5000,
        operatingIncome: 10000 - 6000 - 5000,
      },
      {
        netSales: 10000,
        originalCost: 6000,
        sellingGeneralExpense: 4000,
        operatingIncome: 10000 - 6000 - 4000,
      },
      {
        netSales: 10000,
        originalCost: 6000,
        sellingGeneralExpense: 3999,
        operatingIncome: 10000 - 6000 - 3999,
      },
    ],
    cashFlowData: [
      {
        openingBalance: 400,
        operatingActivitiesCashFlow: 700,
        investingActivitiesCashFlow: -300,
        financingActivitiesCashFlow: 200,
        closingBalance: 400 + 700 + -300 + 200,
      },
      {
        openingBalance: 100000,
        operatingActivitiesCashFlow: -200000,
        investingActivitiesCashFlow: -300,
        financingActivitiesCashFlow: 10000,
        closingBalance: 100000 + -200000 + -300 + 10000,
      },
    ],
  };

  render(): React.ReactNode {
    return (
      <>
        {this.state.profitLossData.map((profitLoss, index) => (
          <ProfitLossBarChart
            key={index}
            netSales={profitLoss.netSales}
            originalCost={profitLoss.originalCost}
            sellingGeneralExpense={profitLoss.sellingGeneralExpense}
            operatingIncome={profitLoss.operatingIncome}
          />
        ))}
        {this.state.cashFlowData.map((cashFlow, index) => (
          <CashFlowBarChart
            key={index}
            openingBalance={cashFlow.openingBalance}
            operatingActivitiesCashFlow={cashFlow.operatingActivitiesCashFlow}
            investingActivitiesCashFlow={cashFlow.investingActivitiesCashFlow}
            financingActivitiesCashFlow={cashFlow.financingActivitiesCashFlow}
            closingBalance={cashFlow.closingBalance}
          />
        ))}
      </>
    );
  }
}
