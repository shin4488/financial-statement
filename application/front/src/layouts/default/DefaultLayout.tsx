import React, { ComponentType } from 'react';
import { useNavigate, NavigateFunction } from 'react-router-dom';
import { bindActionCreators } from 'redux';
import { connect } from 'react-redux';
import { DefaultLayoutProps } from './props';
import {
  Checkbox,
  FormControl,
  FormControlLabel,
  IconButton,
  Link,
  List,
  ListItem,
  ListItemText,
  Tooltip,
  AppBar,
  Toolbar,
  Box,
  Grid,
  Select,
  MenuItem,
  InputLabel,
  SelectChangeEvent,
  Autocomplete,
  Chip,
  TextField,
  InputAdornment,
} from '@mui/material';
import InfoIcon from '@mui/icons-material/Info';
import SearchIcon from '@mui/icons-material/Search';
import { AppDispatch, RootState } from '@/store/store';
import { changeAutoPlayStatus } from '@/store/slices/autoPlayStatusSlice';
import { CashFlowTypeValue, cashFlowTypes } from '@/constants/values';
import {
  changeCashFlowFilter,
  changeStockCodeFilter,
} from '@/store/slices/financialStatementFilterSlice';
import { DefaultLayoutState } from './state';

const autoPlayStatusLocalStorageKey = 'investeeIsStatementAutoPlay';

// store更新・アクセスするための設定
const mapStateToProps = (state: RootState) => ({
  isAutoPlay: state.autoPlayStatus.isAutoPlay,
  cashFlowType: state.financialStatementFilter.cashFlowType,
  stockCodes: state.financialStatementFilter.stockCodes,
});
const mapDispatchToProps = (dispatch: AppDispatch) => ({
  actions: bindActionCreators({ changeAutoPlayStatus }, dispatch),
  cashFlowFilterActions: bindActionCreators({ changeCashFlowFilter }, dispatch),
  stockCodeFilterActions: bindActionCreators(
    { changeStockCodeFilter },
    dispatch,
  ),
});
type DefaultLayoutWithStoreProps = DefaultLayoutProps &
  ReturnType<typeof mapStateToProps> &
  ReturnType<typeof mapDispatchToProps> & {
    navigate: NavigateFunction;
  };

class DefaultLayout extends React.Component<
  DefaultLayoutWithStoreProps,
  DefaultLayoutState
> {
  state: Readonly<DefaultLayoutState> = {
    isQuaryLoaded: false,
  };

  componentDidMount(): void {
    const isAutoPlay =
      (localStorage.getItem(autoPlayStatusLocalStorageKey) || 'true') ===
      'true';
    this.props.actions.changeAutoPlayStatus(isAutoPlay);
    const stockCodes = this.getStockCodeByQuery();
    this.props.stockCodeFilterActions.changeStockCodeFilter(stockCodes);
    this.setState(() => ({
      isQuaryLoaded: true,
    }));
  }

  // ブラウザバック時にも検索条件が変わるようにする
  componentDidUpdate(): void {
    const stockCodes = this.getStockCodeByQuery();
    const isDifferentQuery =
      JSON.stringify(stockCodes) !== JSON.stringify(this.props.stockCodes);
    if (isDifferentQuery) {
      this.props.stockCodeFilterActions.changeStockCodeFilter(stockCodes);
    }
  }

  getStockCodeByQuery(): string[] {
    // urlクエリパラメータから検索条件となる証券コードを取得する
    const url = new URL(window.location.href);
    const joinedStockCodes = url.searchParams.get('stock-codes');
    return joinedStockCodes?.split(',').filter((x) => x !== '') || [];
  }

  render(): React.ReactNode {
    // 検索条件をurlクエリパラメータから取得するまでは画面描画しない
    if (!this.state.isQuaryLoaded) {
      return;
    }

    const infoTooltip = (
      <Tooltip
        placement="bottom-start"
        enterTouchDelay={0}
        leaveTouchDelay={15000}
        title={
          <List dense disablePadding>
            <ListItem disablePadding dense>
              <ListItemText
                primary={
                  <div>
                    <div>上場企業の財務情報が以下の順で表示されます。</div>
                    <div>1. 貸借対照表（数値は総資産比）</div>
                    <div>2. 損益計算書（数値は売上比）</div>
                    <div>3. キャッシュフロー計算書（数値は日本円）</div>
                  </div>
                }
              />
            </ListItem>
            <ListItem disablePadding dense>
              <ListItemText primary="「自動切替」にチェックを入れると上記3つが自動で切替わります。グラフをマウスオーバー/タップすると一時的に切替えが止まります。" />
            </ListItem>
            <ListItem disablePadding dense>
              <ListItemText
                primary="日本会計基準のデータのみ表示可能です。国際会計基準や米国会計基準のデータは表示・検索できません。"
                primaryTypographyProps={{
                  fontWeight: 'bold',
                }}
              />
            </ListItem>
          </List>
        }
      >
        <IconButton size="small">
          <span></span>
          <InfoIcon fontSize="small" />
        </IconButton>
      </Tooltip>
    );

    // 複数ページ共通で使用したい内容があればこのコンポーネントに記述する
    return (
      <>
        <AppBar position="sticky" color="default" sx={{ bgcolor: 'F9F9E0' }}>
          <Toolbar sx={{ ml: -4 }} variant="dense">
            <Box sx={{ flexGrow: 1 }}>
              <Grid container>
                <Grid item xs={3} sm={2}>
                  <FormControl>
                    <FormControlLabel
                      control={
                        <Checkbox
                          checked={this.props.isAutoPlay}
                          onChange={(event) => {
                            this.props.actions.changeAutoPlayStatus(
                              event.target.checked,
                            );
                            localStorage.setItem(
                              autoPlayStatusLocalStorageKey,
                              String(event.target.checked),
                            );
                          }}
                        />
                      }
                      label="自動切替"
                      labelPlacement="start"
                    />
                  </FormControl>
                </Grid>

                <Grid item xs={5} sm={2}>
                  <InputLabel>キャッシュフロー</InputLabel>
                  <Select
                    variant="standard"
                    value={this.props.cashFlowType}
                    onChange={(event: SelectChangeEvent<CashFlowTypeValue>) => {
                      // キャッシュフロータイプのvalueのデータ型は自作のデータ型を使用している
                      this.props.cashFlowFilterActions.changeCashFlowFilter(
                        event.target.value as CashFlowTypeValue,
                      );
                    }}
                  >
                    {cashFlowTypes.map((item) => (
                      <MenuItem key={item.value} value={item.value}>
                        {item.raises_or_falls.map((arrow: string, index) => (
                          <Box
                            component="span"
                            key={index}
                            color={
                              arrow === '↓' ? 'negative.main' : 'positive.main'
                            }
                          >
                            {arrow}
                          </Box>
                        ))}
                        {item.text}
                      </MenuItem>
                    ))}
                  </Select>
                </Grid>

                <Grid item xs={4} sm={8}>
                  <Autocomplete
                    options={[]}
                    freeSolo
                    multiple
                    onChange={(event, stockCodes) => {
                      this.props.stockCodeFilterActions.changeStockCodeFilter(
                        stockCodes,
                      );
                      if (stockCodes.length === 0) {
                        this.props.navigate('/');
                        return;
                      }

                      const joinedStockedCode = stockCodes.join(',');
                      this.props.navigate(`/?stock-codes=${joinedStockedCode}`);
                    }}
                    renderTags={(values: string[], props) =>
                      values.map((value, index) => {
                        return (
                          <Chip
                            label={value}
                            {...props({ index })}
                            key={index}
                          />
                        );
                      })
                    }
                    value={this.props.stockCodes}
                    renderInput={(params) => (
                      <TextField
                        {...params}
                        variant="standard"
                        label="証券コードで検索（複数可）"
                        InputProps={{
                          startAdornment: (
                            <>
                              <InputAdornment position="start">
                                <SearchIcon />
                              </InputAdornment>
                              {params.InputProps.startAdornment}
                              {params.InputProps.endAdornment}
                            </>
                          ),
                        }}
                      />
                    )}
                  />
                </Grid>
              </Grid>
            </Box>

            <Box sx={{ display: { xs: 'flex' } }}>{infoTooltip}</Box>
          </Toolbar>
        </AppBar>

        <Box component="main">{this.props.children}</Box>

        <Box
          component="footer"
          position="fixed"
          bgcolor="white"
          zIndex="10"
          style={{ opacity: 0.7, bottom: 0 }}
        >
          出典:
          <Link
            target="_blank"
            href="https://disclosure2.edinet-fsa.go.jp/WEEK0010.aspx"
            underline="none"
          >
            EDINET閲覧（提出）サイト
          </Link>
          より抜粋して作成
        </Box>
      </>
    );
  }
}

function withNavigate<P>(
  WrappedComponent: ComponentType<P & { navigate: NavigateFunction }>,
) {
  return function WithNavigate(props: Omit<P, 'navigate'>) {
    const navigate = useNavigate();
    return <WrappedComponent {...(props as P)} navigate={navigate} />;
  };
}

const navigate = withNavigate(DefaultLayout);
export default connect(mapStateToProps, mapDispatchToProps)(navigate);
