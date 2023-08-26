import React from 'react';
import BalanceSheetBarCahrt from '@/components/balanceSheetBarChart/BalanceSheetBarChart';
import { BalanceSheetBarChartProps } from '@/components/balanceSheetBarChart/props';
import ProfitLossBarChart from '@/components/profitLossBarChart/ProfitLossBarChart';
import { ProfitLossBarChartProps } from '@/components/profitLossBarChart/props';
import CashFlowBarChart from '@/components/cashFlowBarChart/CashFlowBarChart';
import { CashFlowBarChartProps } from '@/components/cashFlowBarChart/props';

interface DevChartsState {
  balanceSheetData: BalanceSheetBarChartProps[];
  profitLossData: ProfitLossBarChartProps[];
  cashFlowData: CashFlowBarChartProps[];
}

export default class DevCharts extends React.Component<
  unknown,
  DevChartsState
> {
  state: Readonly<DevChartsState> = {
    balanceSheetData: [
      {
        currentAsset: 250000,
        propertyPlantAndEquipment: 50000,
        intangibleAsset: 70000,
        investmentAndOtherAsset: 10000,
        currentLiability: 100000,
        noncurrentLiability: 25000,
        netAsset: 250000 + 50000 + 70000 + 10000 - (100000 + 25000),
      },
      {
        currentAsset: 250000,
        propertyPlantAndEquipment: 50000,
        intangibleAsset: 70000,
        investmentAndOtherAsset: 10000,
        currentLiability: 200000,
        noncurrentLiability: 350000,
        netAsset: 250000 + 50000 + 70000 + 10000 - (200000 + 350000),
      },
    ],
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
        startingCash: 400,
        operatingActivitiesCashFlow: 700,
        investingActivitiesCashFlow: -300,
        financingActivitiesCashFlow: 200,
        endingCash: 400 + 700 + -300 + 200,
      },
      {
        startingCash: 100000,
        operatingActivitiesCashFlow: -200000,
        investingActivitiesCashFlow: -300,
        financingActivitiesCashFlow: 10000,
        endingCash: 100000 + -200000 + -300 + 10000,
      },
    ],
  };

  render(): React.ReactNode {
    return (
      <>
        {this.state.balanceSheetData.map((balanceSheet, index) => (
          <BalanceSheetBarCahrt
            key={index}
            currentAsset={balanceSheet.currentAsset}
            propertyPlantAndEquipment={balanceSheet.propertyPlantAndEquipment}
            intangibleAsset={balanceSheet.intangibleAsset}
            investmentAndOtherAsset={balanceSheet.investmentAndOtherAsset}
            currentLiability={balanceSheet.currentLiability}
            noncurrentLiability={balanceSheet.noncurrentLiability}
            netAsset={balanceSheet.netAsset}
          />
        ))}
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
            startingCash={cashFlow.startingCash}
            operatingActivitiesCashFlow={cashFlow.operatingActivitiesCashFlow}
            investingActivitiesCashFlow={cashFlow.investingActivitiesCashFlow}
            financingActivitiesCashFlow={cashFlow.financingActivitiesCashFlow}
            endingCash={cashFlow.endingCash}
          />
        ))}
      </>
    );
  }
}
