import React from 'react';
import './App.css';
import DefaultLayout from '@/layouts/default/DefaultLayout';
import FinancialStatementList from '@/pages/financialStatementList/FinancialStatementList';
import FirebaseAnalytics from './plugins/firebase/analytics';

export default class App extends React.Component {
  componentDidMount(): void {
    FirebaseAnalytics.getAnalytics();
  }

  render(): React.ReactNode {
    return (
      <DefaultLayout>
        <div className="App">
          <FinancialStatementList />
        </div>
      </DefaultLayout>
    );
  }
}
