import React from 'react';
import './App.css';
import DevCharts from '@/development/pages/DevCharts';
import DefaultLayout from '@/layouts/Default';

function App() {
  return (
    <DefaultLayout
      customChildren={
        <div className="App">
          <DevCharts />
        </div>
      }
    />
  );
}

export default App;
