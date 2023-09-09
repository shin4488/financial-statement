import React from 'react';
import { DefaultLayoutProps } from './props';
import { Link } from '@mui/material';

export default class DefaultLayout extends React.Component<DefaultLayoutProps> {
  render(): React.ReactNode {
    // 複数ページ共通で使用したい内容があればこのコンポーネントに記述する
    return (
      <>
        <div>{this.props.children}</div>
        出典:{' '}
        <Link
          target="_blank"
          href="https://disclosure2dl.edinet-fsa.go.jp/guide/static/disclosure/WZEK0030.html"
        >
          EDINET閲覧（提出）サイト
        </Link>
        より抜粋して作成
      </>
    );
  }
}
