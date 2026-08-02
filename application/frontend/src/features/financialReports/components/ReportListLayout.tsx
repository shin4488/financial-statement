import React from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
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

// 一覧ページのシェル（AppBar・フッター）。DefaultLayoutを再利用しない理由:
// あちらは検索条件をReduxに書く作りで、URLクエリを正とするこの画面と両立しない。
// 自動切替だけはautoPlayStatusSliceを共有する
// （AppCarouselがそこを参照しており、二重管理を避けるため）
export function ReportListLayout({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const dispatch = useDispatch<AppDispatch>();
  const isAutoPlay = useSelector(
    (state: RootState) => state.autoPlayStatus.isAutoPlay,
  );

  const stockCodes =
    searchParams.get('stock-codes')?.split(',').filter(Boolean) ?? [];
  const cashFlowType = (searchParams.get('cash-flow-type') ??
    'none') as CashFlowTypeValue;

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
              primary="日本会計基準とIFRS（連結）に対応しています。米国会計基準など未対応のデータはグラフの代わりにその旨が表示されます。"
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
