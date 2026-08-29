import React from 'react';
import {
  Link as RouterLink,
  useNavigate,
  useSearchParams,
} from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import {
  AppBar,
  Autocomplete,
  Box,
  Checkbox,
  Chip,
  FormControl,
  FormControlLabel,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  Link,
  List,
  ListItem,
  ListItemText,
  MenuItem,
  Select,
  SelectChangeEvent,
  TextField,
  Toolbar,
  Tooltip,
} from '@mui/material';
import InfoIcon from '@mui/icons-material/Info';
import SearchIcon from '@mui/icons-material/Search';
import { AppDispatch, RootState } from '@/store/store';
import { changeAutoPlayStatus } from '@/store/slices/autoPlayStatusSlice';
import {
  autoPlayStatusLocalStorageKey,
  CashFlowTypeValue,
  cashFlowTypes,
} from '@/constants/values';
import { SiteFooter } from '@/features/siteLayout/SiteFooter';
import { siteRoutes } from '@/features/siteLayout/siteRoutes';
import {
  parseCashFlowType,
  parseStockCodes,
} from '@/features/financialReports/searchCriteria';

// 一覧ページのシェル（AppBar・フッター）。検索条件はURLクエリを正とするためReduxには置かず、
// 自動切替だけはautoPlayStatusSliceを共有する
// （AppCarouselがそこを参照しており、二重管理を避けるため）
export function ReportListLayout({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const dispatch = useDispatch<AppDispatch>();
  const isAutoPlay = useSelector(
    (state: RootState) => state.autoPlayStatus.isAutoPlay,
  );

  // 表示（チップ・セレクト）も送信側と同じパースを通す: 表示と検索結果を食い違わせない
  const stockCodes = parseStockCodes(searchParams);
  const cashFlowType = parseCashFlowType(searchParams);

  const applyQuery = (codes: string[], cfType: CashFlowTypeValue) => {
    const next = new URLSearchParams();
    if (codes.length > 0) {
      next.set('stock-codes', codes.join(','));
    }
    if (cfType !== 'none') {
      next.set('cash-flow-type', cfType);
    }
    const query = next.toString();
    navigate(query ? `/?${query}` : '/');
  };

  // その場で分かる最小限のヒントだけを出し、詳しい読み方は静的ページ（/guide）に誘導する
  // （説明を二重に持たない。ツールチップはタッチでも15秒開いたままなのでリンクを押せる）
  const infoTooltip = (
    <Tooltip
      placement="bottom-start"
      enterTouchDelay={0}
      leaveTouchDelay={15000}
      title={
        <List dense disablePadding>
          <ListItem disablePadding dense>
            <ListItemText primary="カードはBS → PL → CFの順に切り替わります（BS・PLは構成比%、CFは円）。" />
          </ListItem>
          <ListItem disablePadding dense>
            <ListItemText
              primary={
                <>
                  グラフの見方・対応している会計基準は
                  <Link
                    component={RouterLink}
                    to={siteRoutes.guide}
                    color="inherit"
                    underline="always"
                  >
                    「財務三表の読み方」
                  </Link>
                  をご覧ください
                </>
              }
            />
          </ListItem>
        </List>
      }
    >
      <IconButton size="small">
        <InfoIcon fontSize="small" />
      </IconButton>
    </Tooltip>
  );

  return (
    <>
      <AppBar position="sticky" color="default">
        <Toolbar sx={{ ml: -4 }} variant="dense">
          <Box sx={{ flexGrow: 1 }}>
            <Grid container>
              <Grid item xs={3} sm={2}>
                <FormControl>
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={isAutoPlay}
                        onChange={(event) => {
                          dispatch(changeAutoPlayStatus(event.target.checked));
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
                  value={cashFlowType}
                  onChange={(event: SelectChangeEvent<CashFlowTypeValue>) => {
                    applyQuery(
                      stockCodes,
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
                  onChange={(event, codes) => {
                    applyQuery(codes as string[], cashFlowType);
                  }}
                  renderTags={(values: string[], props) =>
                    values.map((value, index) => {
                      return (
                        <Chip label={value} {...props({ index })} key={index} />
                      );
                    })
                  }
                  value={stockCodes}
                  renderInput={(params) => (
                    <TextField
                      {...params}
                      variant="standard"
                      label="証券コードで検索（複数可）"
                      InputProps={{
                        ...params.InputProps,
                        startAdornment: (
                          <>
                            <InputAdornment position="start">
                              <SearchIcon />
                            </InputAdornment>
                            {params.InputProps.startAdornment}
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

      <Box component="main">{children}</Box>

      <SiteFooter />
    </>
  );
}
