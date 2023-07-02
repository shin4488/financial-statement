import React from 'react';
import logo from './logo.svg';
import './App.css';
import { TestData } from '@/development/data/TestData';

function App() {
  const a: TestData = {
    aa: 'testですおこk',
    bb: 1234,
    cc: false,
  };
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Edit <code>src/App.tsx</code> and save to reload.
          {a.aa}, {a.bb}, {String(a.cc)}
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>
  );
}

export default App;
