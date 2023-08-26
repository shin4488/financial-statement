import React from 'react';
import './App.css';
import DevCharts from '@/development/pages/DevCharts';
import DefaultLayout from '@/layouts/default/DefaultLayout';

export default class App extends React.Component {
  render(): React.ReactNode {
    return (
      <DefaultLayout>
        <div className="App">
          <DevCharts />
        </div>
      </DefaultLayout>
    );
  }
}
