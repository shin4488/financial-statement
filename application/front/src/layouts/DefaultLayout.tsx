import React, { ReactNode } from 'react';

interface DefaultLayoutProps {
  customChildren: ReactNode;
}

export default class DefaultLayout extends React.Component<DefaultLayoutProps> {
  render(): React.ReactNode {
    // 複数ページ共通で使用したい内容があればこのコンポーネントに記述する
    return <div>{this.props.customChildren}</div>;
  }
}
