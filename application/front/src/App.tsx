import React from 'react';
import './App.css';
import Charts from '@/development/pages/Charts';
import DefaultLayout from '@/layouts/Default';

function App() {
  return (
    <DefaultLayout
      customChildren={
        <div className="App">
          <Charts />
        </div>
      }
    />
  );
}

export default App;
