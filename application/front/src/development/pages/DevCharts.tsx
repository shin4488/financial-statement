import React from 'react';
import { Grid } from '@mui/material';
import Card from '@mui/material/Card';
import CardHeader from '@mui/material/CardHeader';
import CardContent from '@mui/material/CardContent';
import AppCarousel from '@/components/appCarousel/AppCarousel';
import BalanceSheetBarCahrt from '@/components/balanceSheetBarChart/BalanceSheetBarChart';
import { BalanceSheetBarChartProps } from '@/components/balanceSheetBarChart/props';
import ProfitLossBarChart from '@/components/profitLossBarChart/ProfitLossBarChart';
import { ProfitLossBarChartProps } from '@/components/profitLossBarChart/props';
import CashFlowBarChart from '@/components/cashFlowBarChart/CashFlowBarChart';
import { CashFlowBarChartProps } from '@/components/cashFlowBarChart/props';

interface FinancialStatement {
  fiscalYearStartDate: string;
  fiscalYearEndDate: string;
  companyName: string;
  balanceSheet: BalanceSheetBarChartProps;
  profitLoss: ProfitLossBarChartProps;
  cashFlow: CashFlowBarChartProps;
}

interface DevChartsState {
  financialStatements: FinancialStatement[];
}

export default class DevCharts extends React.Component<
  unknown,
  DevChartsState
> {
  state: Readonly<DevChartsState> = {
    financialStatements: [
      {
        fiscalYearStartDate: '2021-07-01',
        fiscalYearEndDate: '2022-06-30',
        companyName: 'オルバヘルスケアホールディングス株式会社',
        balanceSheet: {
          currentAsset: 32908208000,
          propertyPlantAndEquipment: 4304433000,
          intangibleAsset: 814974000,
          investmentAndOtherAsset: 1941055000,
          currentLiability: 28866106000,
          noncurrentLiability: 2009258000,
          netAsset: 9093306000,
        },
        profitLoss: {
          netSales: 107959426000,
          originalCost: 95455447000,
          sellingGeneralExpense: 10430832000,
          operatingIncome: 2073146000,
        },
        cashFlow: {
          startingCash: 2110675000,
          operatingActivitiesCashFlow: 2420642000,
          investingActivitiesCashFlow: -211806000,
          financingActivitiesCashFlow: -1169906000,
          endingCash: 3149605000,
        },
      },
      {
        fiscalYearStartDate: '2021-07-01',
        fiscalYearEndDate: '2022-06-30',
        companyName: '株式会社ＡｍｉｄＡホールディングス',
        balanceSheet: {
          currentAsset: 2182649000,
          propertyPlantAndEquipment: 312374000,
          intangibleAsset: 56027000,
          investmentAndOtherAsset: 34293000,
          currentLiability: 332198000,
          noncurrentLiability: 76480000,
          netAsset: 2176666000,
        },
        profitLoss: {
          netSales: 3055422000,
          originalCost: 1421813000,
          sellingGeneralExpense: 1195403000,
          operatingIncome: 438206000,
        },
        cashFlow: {
          startingCash: 1567892000,
          operatingActivitiesCashFlow: 301753000,
          investingActivitiesCashFlow: -34107000,
          financingActivitiesCashFlow: -77705000,
          endingCash: 1757833000,
        },
      },
      {
        fiscalYearStartDate: '2021-07-01',
        fiscalYearEndDate: '2022-06-30',
        companyName: '一正蒲鉾株式会社',
        balanceSheet: {
          currentAsset: 250000,
          propertyPlantAndEquipment: 50000,
          intangibleAsset: 70000,
          investmentAndOtherAsset: 10000,
          currentLiability: 200000,
          noncurrentLiability: 350000,
          netAsset: 250000 + 50000 + 70000 + 10000 - (200000 + 350000),
        },
        profitLoss: {
          netSales: 10000,
          originalCost: 6000,
          sellingGeneralExpense: 4000,
          operatingIncome: 10000 - 6000 - 4000,
        },
        cashFlow: {
          startingCash: 100000,
          operatingActivitiesCashFlow: -200000,
          investingActivitiesCashFlow: -300,
          financingActivitiesCashFlow: 10000,
          endingCash: 100000 + -200000 + -300 + 10000,
        },
      },
      {
        fiscalYearStartDate: '2021-07-01',
        fiscalYearEndDate: '2022-06-30',
        companyName:
          '株式会社アジュバンホールディングスああああああああああああ aaaaaaaaa bbbbbbbbbbbb ccccccccc',
        balanceSheet: {
          currentAsset: 250000,
          propertyPlantAndEquipment: 50000,
          intangibleAsset: 70000,
          investmentAndOtherAsset: 10000,
          currentLiability: 100000,
          noncurrentLiability: 25000,
          netAsset: 250000 + 50000 + 70000 + 10000 - (100000 + 25000),
        },
        profitLoss: {
          netSales: 10000,
          originalCost: 6000,
          sellingGeneralExpense: 2000,
          operatingIncome: 10000 - 6000 - 2000,
        },
        cashFlow: {
          startingCash: 400,
          operatingActivitiesCashFlow: 700,
          investingActivitiesCashFlow: -300,
          financingActivitiesCashFlow: 200,
          endingCash: 400 + 700 + -300 + 200,
        },
      },
    ],
  };

  render(): React.ReactNode {
    return (
      <Grid container spacing={2} padding={1}>
        {this.state.financialStatements.map((chartData, index) => {
          const balanceSheet = chartData.balanceSheet;
          const profitLoss = chartData.profitLoss;
          const cashFlow = chartData.cashFlow;
          return (
            <Grid item xs={12} md={6} lg={4} key={index}>
              <Card>
                <CardHeader
                  title={
                    <div className="financial-statement-card-header">
                      {chartData.companyName}
                    </div>
                  }
                  subheader={
                    <div className="financial-statement-card-header">
                      {`${chartData.fiscalYearStartDate} - ${chartData.fiscalYearEndDate}`}
                    </div>
                  }
                />
                <CardContent>
                  <AppCarousel>
                    <BalanceSheetBarCahrt
                      currentAsset={balanceSheet.currentAsset}
                      propertyPlantAndEquipment={
                        balanceSheet.propertyPlantAndEquipment
                      }
                      intangibleAsset={balanceSheet.intangibleAsset}
                      investmentAndOtherAsset={
                        balanceSheet.investmentAndOtherAsset
                      }
                      currentLiability={balanceSheet.currentLiability}
                      noncurrentLiability={balanceSheet.noncurrentLiability}
                      netAsset={balanceSheet.netAsset}
                    />
                    <ProfitLossBarChart
                      netSales={profitLoss.netSales}
                      originalCost={profitLoss.originalCost}
                      sellingGeneralExpense={profitLoss.sellingGeneralExpense}
                      operatingIncome={profitLoss.operatingIncome}
                    />
                    <CashFlowBarChart
                      startingCash={cashFlow.startingCash}
                      operatingActivitiesCashFlow={
                        cashFlow.operatingActivitiesCashFlow
                      }
                      investingActivitiesCashFlow={
                        cashFlow.investingActivitiesCashFlow
                      }
                      financingActivitiesCashFlow={
                        cashFlow.financingActivitiesCashFlow
                      }
                      endingCash={cashFlow.endingCash}
                    />
                  </AppCarousel>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    );
  }
}
