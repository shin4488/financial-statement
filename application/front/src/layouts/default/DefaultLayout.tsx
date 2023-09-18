import React from 'react';
import { DefaultLayoutProps } from './props';
import { IconButton, Link, Tooltip } from '@mui/material';
import InfoIcon from '@mui/icons-material/Info';

export default class DefaultLayout extends React.Component<DefaultLayoutProps> {
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
          使い方
          <Tooltip
            placement="right"
            enterTouchDelay={0}
            leaveTouchDelay={6000}
            title={
              <div style={{ fontSize: 13 }}>
                <div>各企業の財務情報が以下の順で表示されます。</div>
                <div>1. 貸借対照表（数値は総資産比）</div>
                <div>2. 損益計算書（数値は売上比）</div>
                <div>3. キャッシュフロー計算書（数値は日本円）</div>
              </div>
            }
          >
            <IconButton>
              <InfoIcon fontSize="small" />
            </IconButton>
          </Tooltip>
        </header>

        <div>{this.props.children}</div>

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
