import React from 'react';
import { Grid, Link } from '@mui/material';
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
import { CompanyFinancialStatement } from '@/__generated__/graphql';
import ChartAlternative from '@/components/chartAlternative/ChartAlternative';

interface FinancialStatement {
  fiscalYearStartDate: string;
  fiscalYearEndDate: string;
  companyName: string;
  stockCode: string;
  hasConsolidatedFinancialStatement: boolean;
  consolidatedInductoryCode: string;
  nonConsolidatedInductoryCode: string;
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
            const balanceSheet = chartData.balanceSheet;
            const profitLoss = chartData.profitLoss;
            const cashFlow = chartData.cashFlow;
            const consolidationTypeLabel =
              chartData.hasConsolidatedFinancialStatement ? '連結' : '単体';
            const isBank =
              (chartData.hasConsolidatedFinancialStatement &&
                chartData.consolidatedInductoryCode === 'bnk') ||
              (!chartData.hasConsolidatedFinancialStatement &&
                chartData.nonConsolidatedInductoryCode === 'bnk');

            return (
              <Grid item xs={12} md={6} lg={4} key={index}>
                <Card>
                  <CardHeader
                    title={
                      <div className="financial-statement-card-header">
                        <Link
                          title={`${chartData.companyName}（株探）`}
                          underline="none"
                          target="_blank"
                          href={`https://kabutan.jp/stock/?code=${chartData.stockCode}`}
                        >
                          {chartData.companyName}
                        </Link>
                      </div>
                    }
                    subheader={
                      <div className="financial-statement-card-header">
                        {`${chartData.fiscalYearStartDate} - ${chartData.fiscalYearEndDate}（${consolidationTypeLabel}）`}
                      </div>
                    }
                  />
                  <CardContent>
                    <AppCarousel>
                      {/* 貸借対照表 */}
                      {isBank ? (
                        <ChartAlternative>
                          貸借対照表:
                          金融機関のデータ表示には対応しておりません。
                        </ChartAlternative>
                      ) : (
                        <BalanceSheetBarCahrt
                          amount={balanceSheet.amount}
                          ratio={balanceSheet.ratio}
                        />
                      )}

                      {/* 損益計算書 */}
                      {isBank ? (
                        <ChartAlternative>
                          損益計算書:
                          金融機関のデータ表示には対応しておりません。
                        </ChartAlternative>
                      ) : (
                        <ProfitLossBarChart
                          amount={profitLoss.amount}
                          ratio={profitLoss.ratio}
                        />
                      )}

                      {/* キャッシュフロー計算書 */}
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
          companyFinancialStatements(limit: ` +
          financialStatementOffsetUnit +
          `, offset: ` +
          offset +
          `) {
            fiscalYearStartDate
            fiscalYearEndDate
            filingDate
            stockCode
            companyJapaneseName
            hasConsolidatedFinancialStatement
            consolidatedInductoryCode
            nonConsolidatedInductoryCode
            balanceSheet {
              amount {
                currentAsset
                propertyPlantAndEquipment
                intangibleAsset
                investmentAndOtherAsset
                currentLiability
                noncurrentLiability
                netAsset
              }
              ratio {
                currentAsset
                propertyPlantAndEquipment
                intangibleAsset
                investmentAndOtherAsset
                currentLiability
                noncurrentLiability
                netAsset
              }
            }
            profitLoss {
              amount {
                netSales
                originalCost
                sellingGeneralExpense
                operatingIncome
              }
              ratio {
                netSales
                originalCost
                sellingGeneralExpense
                operatingIncome
              }
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
            offset === 0 && state.financialStatements.length !== 0;

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
    const balanceSheetAmount = financialStatementResponse.balanceSheet?.amount;
    const balanceSheetRatio = financialStatementResponse.balanceSheet?.ratio;
    const profitLossAmount = financialStatementResponse.profitLoss?.amount;
    const profitLossRatio = financialStatementResponse.profitLoss?.ratio;
    const cashFlow = financialStatementResponse.cashFlow;

    return {
      fiscalYearStartDate: StringUtil.toBlankIfEmpty(
        financialStatementResponse.fiscalYearStartDate,
      ),
      fiscalYearEndDate: StringUtil.toBlankIfEmpty(
        financialStatementResponse.fiscalYearEndDate,
      ),
      stockCode: StringUtil.toBlankIfEmpty(
        financialStatementResponse.stockCode,
      ).slice(0, -1),
      companyName: StringUtil.toBlankIfEmpty(
        financialStatementResponse.companyJapaneseName,
      ),
      hasConsolidatedFinancialStatement:
        financialStatementResponse.hasConsolidatedFinancialStatement || false,
      consolidatedInductoryCode: StringUtil.toBlankIfEmpty(
        financialStatementResponse.consolidatedInductoryCode,
      ),
      nonConsolidatedInductoryCode: StringUtil.toBlankIfEmpty(
        financialStatementResponse.nonConsolidatedInductoryCode,
      ),
      balanceSheet: {
        amount: {
          currentAsset: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.currentAsset,
          ),
          propertyPlantAndEquipment: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.propertyPlantAndEquipment,
          ),
          intangibleAsset: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.intangibleAsset,
          ),
          investmentAndOtherAsset: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.investmentAndOtherAsset,
          ),
          currentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.currentLiability,
          ),
          noncurrentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetAmount?.noncurrentLiability,
          ),
          netAsset: NumberUtil.toNumberOrDefault(balanceSheetAmount?.netAsset),
        },
        ratio: {
          currentAsset: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.currentAsset,
          ),
          propertyPlantAndEquipment: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.propertyPlantAndEquipment,
          ),
          intangibleAsset: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.intangibleAsset,
          ),
          investmentAndOtherAsset: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.investmentAndOtherAsset,
          ),
          currentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.currentLiability,
          ),
          noncurrentLiability: NumberUtil.toNumberOrDefault(
            balanceSheetRatio?.noncurrentLiability,
          ),
          netAsset: NumberUtil.toNumberOrDefault(balanceSheetRatio?.netAsset),
        },
      },
      profitLoss: {
        amount: {
          netSales: NumberUtil.toNumberOrDefault(profitLossAmount?.netSales),
          originalCost: NumberUtil.toNumberOrDefault(
            profitLossAmount?.originalCost,
          ),
          sellingGeneralExpense: NumberUtil.toNumberOrDefault(
            profitLossAmount?.sellingGeneralExpense,
          ),
          operatingIncome: NumberUtil.toNumberOrDefault(
            profitLossAmount?.operatingIncome,
          ),
        },
        ratio: {
          netSales: NumberUtil.toNumberOrDefault(profitLossRatio?.netSales),
          originalCost: NumberUtil.toNumberOrDefault(
            profitLossRatio?.originalCost,
          ),
          sellingGeneralExpense: NumberUtil.toNumberOrDefault(
            profitLossRatio?.sellingGeneralExpense,
          ),
          operatingIncome: NumberUtil.toNumberOrDefault(
            profitLossRatio?.operatingIncome,
          ),
        },
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
