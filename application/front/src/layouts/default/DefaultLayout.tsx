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
  Tooltip,
} from '@mui/material';
import InfoIcon from '@mui/icons-material/Info';
import { AppDispatch, RootState } from '@/store/store';
import { changeAutoPlayStatus } from '@/store/slices/autoPlayStatusSlice';

const autoPlayStatusLocalStorageKey = 'flazaIsStatementAutoPlay';

// store更新・アクセスするための設定
const mapStateToProps = (state: RootState) => ({
  isAutoPlay: state.autoPlayStatus.isAutoPlay,
});
const mapDispatchToProps = (dispatch: AppDispatch) => ({
  actions: bindActionCreators({ changeAutoPlayStatus }, dispatch),
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
    const fixedStyle: React.CSSProperties = {
      backgroundColor: 'white',
      position: 'fixed',
      zIndex: 10,
    };

    // 複数ページ共通で使用したい内容があればこのコンポーネントに記述する
    return (
      <>
        <header style={{ ...fixedStyle, opacity: 0.8, top: 0 }}>
          <Tooltip
            placement="bottom-start"
            enterTouchDelay={0}
            leaveTouchDelay={6000}
            title={
              <div style={{ fontSize: 13 }}>
                <div>各企業の財務情報が以下の順で表示されます。</div>
                <div>1. 貸借対照表（数値は総資産比）</div>
                <div>2. 損益計算書（数値は売上比）</div>
                <div>3. キャッシュフロー計算書（数値は日本円）</div>
                <div>
                  財務情報の表示を自動切替したい場合は、「財務情報を自動で切替える」にチェックを入れてください。
                </div>
              </div>
            }
          >
            <IconButton size="small">
              <span>使い方</span>
              <InfoIcon fontSize="small" />
            </IconButton>
          </Tooltip>
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
              label="財務情報を自動で切替える"
              labelPlacement="start"
            />
          </FormControl>
        </header>

        <div style={{ top: 13, position: 'absolute' }}>
          {this.props.children}
        </div>

        <footer style={{ ...fixedStyle, opacity: 0.7, bottom: 0 }}>
          出典:{' '}
          <Link
            target="_blank"
            href="https://disclosure2.edinet-fsa.go.jp/WEEK0010.aspx"
            underline="none"
          >
            EDINET閲覧（提出）サイト
          </Link>
          より抜粋して作成
        </footer>
      </>
    );
  }
}

export default connect(mapStateToProps, mapDispatchToProps)(DefaultLayout);
