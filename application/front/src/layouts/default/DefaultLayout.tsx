import React from 'react';
import { DefaultLayoutProps } from './props';

export default class DefaultLayout extends React.Component<DefaultLayoutProps> {
  render(): React.ReactNode {
    // 複数ページ共通で使用したい内容があればこのコンポーネントに記述する
    return <div>{this.props.children}</div>;
  }
}
