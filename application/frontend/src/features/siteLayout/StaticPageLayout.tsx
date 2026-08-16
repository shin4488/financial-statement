import React, { useEffect } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import {
  AppBar,
  Box,
  Container,
  Link,
  Toolbar,
  Typography,
} from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';
import { SiteFooter } from './SiteFooter';
import { siteRoutes } from './siteRoutes';
import { usePageMeta } from './usePageMeta';

interface StaticPageLayoutProps {
  title: string; // 見出し（<title>にも「| investee」付きで使う）
  description: string; // meta description
  path: string; // siteRoutesの値。canonicalに使う
  children: React.ReactNode;
}

// 静的ページ（サイト説明・読み方・ポリシー・連絡先）の共通シェル。
// AppBar・フッターの構成と配色は一覧ページ（ReportListLayout）に揃え、
// 見出しとメタ情報の設定だけを担う。検索UIは持たず、一覧ページへの導線だけを置く
export function StaticPageLayout({
  title,
  description,
  path,
  children,
}: StaticPageLayoutProps) {
  usePageMeta({ title: `${title} | investee`, description, path });
  // 一覧ページを下までスクロールした位置からフッターのリンクで遷移すると、
  // スクロール位置が引き継がれてページ途中から表示されるため先頭に戻す
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [path]);

  return (
    <>
      <AppBar position="sticky" color="default">
        <Toolbar variant="dense">
          <Link
            component={RouterLink}
            to={siteRoutes.top}
            underline="none"
            color="inherit"
            sx={{ fontWeight: 'bold', fontSize: '1.1rem' }}
          >
            investee
          </Link>
          <Box sx={{ flexGrow: 1 }} />
          <Link
            component={RouterLink}
            to={siteRoutes.top}
            underline="hover"
            sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5 }}
          >
            <SearchIcon fontSize="small" />
            財務諸表を検索する
          </Link>
        </Toolbar>
      </AppBar>

      {/* 下部固定フッターに末尾が隠れないよう、下側の余白を大きめに取る */}
      <Container component="main" maxWidth="md" sx={{ pt: 3, pb: 12 }}>
        <Typography variant="h5" component="h1" gutterBottom>
          {title}
        </Typography>
        {children}
      </Container>

      <SiteFooter />
    </>
  );
}
