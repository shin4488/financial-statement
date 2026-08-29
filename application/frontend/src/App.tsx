import React, { useEffect } from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import './App.css';
import FinancialReportListPage from '@/features/financialReports/FinancialReportListPage';
import AboutPage from '@/features/staticPages/AboutPage';
import ContactPage from '@/features/staticPages/ContactPage';
import GuidePage from '@/features/staticPages/GuidePage';
import PrivacyPolicyPage from '@/features/staticPages/PrivacyPolicyPage';
import { siteRoutes } from '@/features/siteLayout/siteRoutes';
import { initializeAnalytics } from './plugins/firebase/analytics';
import { CssBaseline, ThemeProvider, createTheme } from '@mui/material';

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

export default function App() {
  useEffect(() => {
    initializeAnalytics();
  }, []);

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <BrowserRouter>
        <Routes>
          {/* 静的ページ（サイト説明・規約系）。一覧ページは残りの全URLを受ける */}
          <Route path={siteRoutes.about} element={<AboutPage />} />
          <Route path={siteRoutes.guide} element={<GuidePage />} />
          <Route path={siteRoutes.privacy} element={<PrivacyPolicyPage />} />
          <Route path={siteRoutes.contact} element={<ContactPage />} />
          <Route path="*" element={<FinancialReportListPage />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}
