import React, { useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import { Box, Link, Menu, MenuItem } from '@mui/material';
import ArrowDropUpIcon from '@mui/icons-material/ArrowDropUp';
import { footerLinks } from './siteRoutes';

// 全ページ共通のフッター（画面下部に固定）。出典表記と、サイト説明・規約系ページへの導線を持つ。
// 一覧ページと静的ページの両方から使う。
//
// 常に1行に収める方針: 固定フッターは行数が増えた分だけカードを隠すため。
// - 広い画面（lg以上）: 4つのリンクをそのまま並べる
// - それ未満: リンクを「サイト情報」メニューに畳む。スマホ幅（xs）ではさらに
//   出典表記の末尾（より抜粋して作成）を省き、文字も少し小さくして1行に収める
export function SiteFooter() {
  return (
    <Box
      component="footer"
      position="fixed"
      bgcolor="white"
      zIndex="10"
      style={{ opacity: 0.7, bottom: 0 }}
      sx={{
        display: 'flex',
        alignItems: 'center',
        whiteSpace: 'nowrap',
        columnGap: 2,
        px: 0.5,
        // sm以上は本文と同じ1rem（'inherit'はsxではtypographyのvariant名と解釈され効かない）
        fontSize: { xs: '0.8rem', sm: '1rem' },
      }}
    >
      <span>
        出典:
        <Link
          target="_blank"
          // MUIのLinkはrelを自動付与しないため明示する。
          // noreferrer: 検索条件を含むURLが遷移先に渡るのを防ぐ
          rel="noopener noreferrer"
          href="https://disclosure2.edinet-fsa.go.jp/WEEK0010.aspx"
          underline="none"
        >
          EDINET閲覧（提出）サイト
        </Link>
        <Box component="span" sx={{ display: { xs: 'none', sm: 'inline' } }}>
          より抜粋して作成
        </Box>
      </span>
      <Box
        component="span"
        sx={{
          display: { xs: 'none', lg: 'inline-flex' },
          columnGap: 2,
        }}
      >
        {footerLinks.map((item) => (
          <Link
            key={item.to}
            component={RouterLink}
            to={item.to}
            underline="none"
          >
            {item.label}
          </Link>
        ))}
      </Box>
      <Box component="span" sx={{ display: { xs: 'inline-flex', lg: 'none' } }}>
        <SiteLinksMenu />
      </Box>
    </Box>
  );
}

// 「サイト情報 ▴」を押すと上方向にメニューが開き、4つのリンクを選べる
function SiteLinksMenu() {
  const [anchor, setAnchor] = useState<HTMLElement | null>(null);
  const close = () => setAnchor(null);
  return (
    <>
      <Link
        component="button"
        type="button"
        underline="none"
        onClick={(event: React.MouseEvent<HTMLElement>) =>
          setAnchor(event.currentTarget)
        }
        // component="button" はブラウザ既定のボタン書体になるため、周囲の文字に揃える
        sx={{ font: 'inherit', display: 'inline-flex', alignItems: 'center' }}
      >
        サイト情報
        <ArrowDropUpIcon fontSize="small" />
      </Link>
      <Menu
        anchorEl={anchor}
        open={Boolean(anchor)}
        onClose={close}
        anchorOrigin={{ vertical: 'top', horizontal: 'left' }}
        transformOrigin={{ vertical: 'bottom', horizontal: 'left' }}
      >
        {footerLinks.map((item) => (
          <MenuItem
            key={item.to}
            component={RouterLink}
            to={item.to}
            onClick={close}
          >
            {item.label}
          </MenuItem>
        ))}
      </Menu>
    </>
  );
}
