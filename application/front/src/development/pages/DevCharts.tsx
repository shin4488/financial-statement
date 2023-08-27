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
import ApolloClientService from '@/plugins/apollo/service';
import { NumberUtil } from '@/plugins/utils/numberUtil';
import StringUtil from '@/plugins/utils/stringUtil';

interface FinancialStatement {
  fiscalYearStartDate: string;
  fiscalYearEndDate: string;
  companyName: string;
  balanceSheet: BalanceSheetBarChartProps;
  profitLoss: ProfitLossBarChartProps;
  cashFlow: CashFlowBarChartProps;
}

interface DevChartsState {
  apolloService: ApolloClientService;
  financialStatements: FinancialStatement[];
}

export default class DevCharts extends React.Component<
  unknown,
  DevChartsState
> {
  state: Readonly<DevChartsState> = {
    apolloService: new ApolloClientService(),
    financialStatements: [],
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

  componentDidMount(): void {
    this.state.apolloService
      .query(
        `
        query {
          companyFinancialStatements(limit: 123) {
            fiscalYearStartDate
            fiscalYearEndDate
            companyName
            balanceSheet {
              currentAsset
              propertyPlantAndEquipment
              intangibleAsset
              investmentAndOtherAsset
              currentLiability
              noncurrentLiability
              netAsset
            }
            profitLoss {
              netSales
              originalCost
              sellingGeneralExpense
              operatingIncome
            }
            cashFlow {
              startingCash
              operatingActivitiesCashFlow
              investingActivitiesCashFlow
              financingActivitiesCashFlow
              endingCash
            }
          }
        }
        `,
      )
      .then((result) => {
        const financialStatements = result.companyFinancialStatements;
        if (
          financialStatements === undefined ||
          financialStatements === null ||
          financialStatements.length === 0
        ) {
          return;
        }

        this.setState({
          financialStatements: financialStatements.map((statement) => {
            const balanceSheet = statement.balanceSheet;
            const profitLoss = statement.profitLoss;
            const cashFlow = statement.cashFlow;
            return {
              fiscalYearStartDate: StringUtil.toBlankIfEmpty(
                statement.fiscalYearStartDate,
              ),
              fiscalYearEndDate: StringUtil.toBlankIfEmpty(
                statement.fiscalYearEndDate,
              ),
              companyName: StringUtil.toBlankIfEmpty(statement.companyName),
              balanceSheet: {
                currentAsset: NumberUtil.toNumberOrDefault(
                  balanceSheet?.currentAsset,
                ),
                propertyPlantAndEquipment: NumberUtil.toNumberOrDefault(
                  balanceSheet?.propertyPlantAndEquipment,
                ),
                intangibleAsset: NumberUtil.toNumberOrDefault(
                  balanceSheet?.intangibleAsset,
                ),
                investmentAndOtherAsset: NumberUtil.toNumberOrDefault(
                  balanceSheet?.investmentAndOtherAsset,
                ),
                currentLiability: NumberUtil.toNumberOrDefault(
                  balanceSheet?.currentLiability,
                ),
                noncurrentLiability: NumberUtil.toNumberOrDefault(
                  balanceSheet?.noncurrentLiability,
                ),
                netAsset: NumberUtil.toNumberOrDefault(balanceSheet?.netAsset),
              },
              profitLoss: {
                netSales: NumberUtil.toNumberOrDefault(profitLoss?.netSales),
                originalCost: NumberUtil.toNumberOrDefault(
                  profitLoss?.originalCost,
                ),
                sellingGeneralExpense: NumberUtil.toNumberOrDefault(
                  profitLoss?.sellingGeneralExpense,
                ),
                operatingIncome: NumberUtil.toNumberOrDefault(
                  profitLoss?.operatingIncome,
                ),
              },
              cashFlow: {
                startingCash: NumberUtil.toNumberOrDefault(
                  cashFlow?.startingCash,
                ),
                operatingActivitiesCashFlow: NumberUtil.toNumberOrDefault(
                  cashFlow?.operatingActivitiesCashFlow,
                ),
                investingActivitiesCashFlow: NumberUtil.toNumberOrDefault(
                  cashFlow?.investingActivitiesCashFlow,
                ),
                financingActivitiesCashFlow: NumberUtil.toNumberOrDefault(
                  cashFlow?.financingActivitiesCashFlow,
                ),
                endingCash: NumberUtil.toNumberOrDefault(cashFlow?.endingCash),
              },
            };
          }),
        });
      });
  }
}
