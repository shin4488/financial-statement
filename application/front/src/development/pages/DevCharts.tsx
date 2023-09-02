import React from 'react';
import { Grid } from '@mui/material';
import Card from '@mui/material/Card';
import CardHeader from '@mui/material/CardHeader';
import CardContent from '@mui/material/CardContent';
import CircularProgress from '@mui/material/CircularProgress';
import InfiniteScroll from 'react-infinite-scroller';
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
import { financialStatementOffsetUnit } from '@/constants/values';
import { EnvUtil } from '@/plugins/utils/envUtil';
import { CompanyFinancialStatement } from '@/__generated__/graphql';

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
  shouldLoadMore: boolean;
  financialStatements: FinancialStatement[];
}

export default class DevCharts extends React.Component<
  unknown,
  DevChartsState
> {
  state: Readonly<DevChartsState> = {
    apolloService: new ApolloClientService(),
    shouldLoadMore: true,
    financialStatements: [],
  };

  render(): React.ReactNode {
    return (
      <>
        <Grid container spacing={2} padding={1}>
          {this.state.financialStatements.map((chartData, index) => {
            const balanceSheetAmount = chartData.balanceSheet.amount;
            const balanceSheetRatio = chartData.balanceSheet.ratio;
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
                        amount={balanceSheetAmount}
                        ratio={balanceSheetRatio}
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

        <InfiniteScroll
          loadMore={(page) => {
            this.load((page - 1) * financialStatementOffsetUnit);
          }}
          hasMore={this.state.shouldLoadMore}
          loader={<CircularProgress key={1} style={{ marginBottom: 5 }} />}
        >
          {this.state.financialStatements.map((_, index) => (
            <React.Fragment key={index}></React.Fragment>
          ))}
        </InfiniteScroll>
      </>
    );
  }

  load(offset: number): void {
    this.state.apolloService
      .query(
        `
        query {
          companyFinancialStatements(limit: 123, offset: ${offset}) {
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
          // TODO:前回のsetStateの内容が画面に描画される前に次のsetStateを行ってしまうと、chartのlabelListが表示されなくなる（それを回避するために遅らせてsetStateしている）
          setTimeout(() => {
            this.setState({ shouldLoadMore: false });
          }, 500);
          return;
        }

        // TODO:前回のsetStateの内容が画面に描画される前に次のsetStateを行ってしまうと、chartのlabelListが表示されなくなる（一度に取得するデータ件数が多いためすぐには問題にならなさそう）
        this.setState((state) => {
          // Reactは開発時のみデフォルトでStrictModeとなっており、StrictModeだと初期表示で2回レンダリングされるため、開発時は同じデータが2重で表示されるのを防ぐ
          const isSecondRendering =
            EnvUtil.isDevelopment() &&
            offset === 0 &&
            state.financialStatements.length !== 0;

          return {
            shouldLoadMore:
              financialStatements.length === financialStatementOffsetUnit,
            // 下へスクロースするため、末尾へ取得データを追加する
            financialStatements: isSecondRendering
              ? state.financialStatements
              : [
                  ...state.financialStatements,
                  ...financialStatements.map((statement) =>
                    this.mapFinancialStatementFromResponseToState(statement),
                  ),
                ],
          };
        });
      });
  }

  mapFinancialStatementFromResponseToState(
    financialStatementResponse: CompanyFinancialStatement,
  ): FinancialStatement {
    const balanceSheet = financialStatementResponse.balanceSheet;
    const profitLoss = financialStatementResponse.profitLoss;
    const cashFlow = financialStatementResponse.cashFlow;

    return {
      fiscalYearStartDate: StringUtil.toBlankIfEmpty(
        financialStatementResponse.fiscalYearStartDate,
      ),
      fiscalYearEndDate: StringUtil.toBlankIfEmpty(
        financialStatementResponse.fiscalYearEndDate,
      ),
      companyName: StringUtil.toBlankIfEmpty(
        financialStatementResponse.companyName,
      ),
      balanceSheet: {
        amount: {
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
        ratio: {
          currentAsset: 60,
          propertyPlantAndEquipment: 20,
          intangibleAsset: 15,
          investmentAndOtherAsset: 5,
          currentLiability: 40,
          noncurrentLiability: 15,
          netAsset: 45,
        },
      },
      profitLoss: {
        netSales: NumberUtil.toNumberOrDefault(profitLoss?.netSales),
        originalCost: NumberUtil.toNumberOrDefault(profitLoss?.originalCost),
        sellingGeneralExpense: NumberUtil.toNumberOrDefault(
          profitLoss?.sellingGeneralExpense,
        ),
        operatingIncome: NumberUtil.toNumberOrDefault(
          profitLoss?.operatingIncome,
        ),
      },
      cashFlow: {
        startingCash: NumberUtil.toNumberOrDefault(cashFlow?.startingCash),
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
  }
}
