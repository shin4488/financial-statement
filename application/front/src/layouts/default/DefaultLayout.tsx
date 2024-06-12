import React from 'react';
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
import { cashFlowTypes } from '@/constants/values';
import {
  changeCashFlowFilter,
  changeStockCodeFilter,
} from '@/store/slices/financialStatementFilterSlice';

const autoPlayStatusLocalStorageKey = 'flazaIsStatementAutoPlay';

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
  ReturnType<typeof mapDispatchToProps>;

class DefaultLayout extends React.Component<DefaultLayoutWithStoreProps> {
  componentDidMount(): void {
    const isAutoPlay =
      (localStorage.getItem(autoPlayStatusLocalStorageKey) || 'true') ===
      'true';
    this.props.actions.changeAutoPlayStatus(isAutoPlay);
  }

  render(): React.ReactNode {
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
              <ListItemText primary="訂正報告書が最近出された財務情報は、昨年以前の会計年度でも上位に表示されます。" />
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
                    onChange={(event: SelectChangeEvent) => {
                      this.props.cashFlowFilterActions.changeCashFlowFilter(
                        event.target.value,
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
                    renderInput={(params) => (
                      <TextField
                        {...params}
                        variant="standard"
                        label="証券コードで検索（複数可）"
                        type="number"
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
          出典:{' '}
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

export default connect(mapStateToProps, mapDispatchToProps)(DefaultLayout);
