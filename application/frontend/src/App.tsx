import React from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import './types/mui/styles.d';
import './App.css';
import FinancialReportListPage from '@/features/financialReports/FinancialReportListPage';
import FirebaseAnalytics from './plugins/firebase/analytics';
import { CssBaseline, ThemeProvider, createTheme } from '@mui/material';

export default class App extends React.Component {
  componentDidMount(): void {
    FirebaseAnalytics.getAnalytics();
  }

  render(): React.ReactNode {
    const theme = createTheme({
      palette: {
        positive: {
          main: '#5A96E3',
          light: '#5A96E3',
          dark: '#A1C2F1',
          contrastText: '#fff',
        },
        negative: {
          main: '#E48586',
          light: '#E48586',
          dark: '#FF9EAA',
          contrastText: '#fff',
        },
      },
    });

    return (
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <BrowserRouter>
          <Routes>
            <Route path="*" element={<FinancialReportListPage />} />
          </Routes>
        </BrowserRouter>
      </ThemeProvider>
    );
  }
}
