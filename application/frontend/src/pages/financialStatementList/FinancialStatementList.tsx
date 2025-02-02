import React from 'react';
import { Grid, Link } from '@mui/material';
import Card from '@mui/material/Card';
import CardHeader from '@mui/material/CardHeader';
import CardContent from '@mui/material/CardContent';
import CircularProgress from '@mui/material/CircularProgress';
import InfiniteScroll from 'react-infinite-scroller';
import AppCarousel from '@/components/appCarousel/AppCarousel';
import BalanceSheetBarCahrt from '@/components/balanceSheetBarChart/BalanceSheetBarChart';
import ProfitLossBarChart from '@/components/profitLossBarChart/ProfitLossBarChart';
import CashFlowBarChart from '@/components/cashFlowBarChart/CashFlowBarChart';
import { financialStatementOffsetUnit } from '@/constants/values';
import ChartAlternative from '@/components/chartAlternative/ChartAlternative';
import { FinancialStatementListState } from './state';
import FinancialStatementListStateService from './service';
import FirebaseAnalytics from '@/plugins/firebase/analytics';
import { RootState } from '@/store/store';
import { connect } from 'react-redux';

const mapStateToProps = (state: RootState) => {
  return {
    cashFlowType: state.financialStatementFilter.cashFlowType,
    stockCodes: state.financialStatementFilter.stockCodes,
  };
};
type FinancialStatementListWithStoreProps = ReturnType<typeof mapStateToProps>;

class FinancialStatementList extends React.Component<
  FinancialStatementListWithStoreProps,
  FinancialStatementListState
> {
  state: Readonly<FinancialStatementListState> = {
    service: new FinancialStatementListStateService(),
    shouldLoadMore: true,
    financialStatements: [],
    infiniteScrollKey: Math.random(),
  };

  componentDidUpdate(
    previousProps: FinancialStatementListWithStoreProps,
  ): void {
    const sameCashFlowFilter =
      this.props.cashFlowType === previousProps.cashFlowType;
    const sameStockCodes =
      JSON.stringify(this.props.stockCodes) ===
      JSON.stringify(previousProps.stockCodes);
    // 検索条件の状態が変わっていないのであれば、現在の表示は残しておく
    if (sameCashFlowFilter && sameStockCodes) {
      return;
    }

    // 条件が1つでも変わるとデータを再取得するため、現在表示しているデータは表示削除する
    this.setState(() => ({
      financialStatements: [],
      infiniteScrollKey: Math.random(),
      shouldLoadMore: true,
    }));
  }

  render(): React.ReactNode {
    return (
      <>
        <Grid container spacing={2} padding={1}>
          {this.state.financialStatements.map((statement, index) => {
            const balanceSheet = statement.balanceSheet;
            const profitLoss = statement.profitLoss;
            const cashFlow = statement.cashFlow;
            const consolidationTypeLabel =
              statement.hasConsolidatedFinancialStatement ? '連結' : '単体';
            const ignoredInductoryCodes = ['bnk', 'ele'];
            const isBankOrElectricity =
              (statement.hasConsolidatedFinancialStatement &&
                ignoredInductoryCodes.includes(
                  statement.consolidatedInductoryCode.toLowerCase(),
                )) ||
              (!statement.hasConsolidatedFinancialStatement &&
                ignoredInductoryCodes.includes(
                  statement.nonConsolidatedInductoryCode.toLowerCase(),
                ));

            return (
              <Grid item xs={12} md={6} lg={4} key={index}>
                <Card>
                  <CardHeader
                    title={
                      <div className="financial-statement-card-header">
                        <Link
                          title={`${statement.companyName}（株探）`}
                          underline="none"
                          target="_blank"
                          href={`https://kabutan.jp/stock/?code=${statement.stockCode}`}
                        >
                          <span
                            onClick={() =>
                              FirebaseAnalytics.logClickEvent({
                                content_type: 'url',
                                link_domain: 'kabutan.jp',
                                link_url: `https://kabutan.jp/stock/?code=${statement.stockCode}`,
                                custom_stock_code: statement.stockCode,
                                custom_title: statement.companyName,
                                custom_timespan: `${statement.fiscalYearStartDate}-${statement.fiscalYearEndDate}`,
                              })
                            }
                          >
                            {statement.companyName}
                          </span>
                        </Link>
                      </div>
                    }
                    subheader={
                      <div className="financial-statement-card-header">
                        {`${statement.stockCode} : ${statement.fiscalYearStartDate} - ${statement.fiscalYearEndDate}（${consolidationTypeLabel}）`}
                      </div>
                    }
                  />
                  <CardContent>
                    <AppCarousel>
                      {/* 貸借対照表 */}
                      {isBankOrElectricity ? (
                        <ChartAlternative>
                          貸借対照表:
                          金融機関や電気事業者のデータ表示には対応しておりません。
                        </ChartAlternative>
                      ) : (
                        <BalanceSheetBarCahrt
                          amount={balanceSheet.amount}
                          ratio={balanceSheet.ratio}
                        />
                      )}

                      {/* 損益計算書 */}
                      {isBankOrElectricity ? (
                        <ChartAlternative>
                          損益計算書:
                          金融機関や電気事業者のデータ表示には対応しておりません。
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

        {/* 検索条件変更時にInfiniteScrollのpageがリセットするための対応。親要素のkeyを更新するとpageが0にリセットされる */}
        {/* https://github.com/danbovey/react-infinite-scroller/issues/12#issuecomment-339375017 */}
        <div key={this.state.infiniteScrollKey}>
          <InfiniteScroll
            loadMore={(page) => {
              this.load((page - 1) * financialStatementOffsetUnit);
              FirebaseAnalytics.logLoadMoreStatementsEvent({ page: page });
            }}
            hasMore={this.state.shouldLoadMore}
            loader={<CircularProgress key={1} style={{ marginBottom: 5 }} />}
          >
            {this.state.financialStatements.map((_, index) => (
              <React.Fragment key={index}></React.Fragment>
            ))}
          </InfiniteScroll>
        </div>
      </>
    );
  }

  load(offset: number): void {
    const condition = {
      cashFlowType: this.props.cashFlowType,
      stockCodes: this.props.stockCodes,
    };
    this.state.service.query(offset, condition).then((result) => {
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
                  this.state.service.mapFinancialStatementFromResponseToState(
                    statement,
                  ),
                ),
              ],
        };
      });
    });
  }
}

export default connect(mapStateToProps)(FinancialStatementList);
