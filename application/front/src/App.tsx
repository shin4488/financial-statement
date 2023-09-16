import React from 'react';
import './App.css';
import DefaultLayout from '@/layouts/default/DefaultLayout';
import FinancialStatementList from '@/pages/financialStatementList/FinancialStatementList';

export default class App extends React.Component {
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
