import React from 'react';
import { Link as RouterLink } from 'react-router-dom';
import {
  Link,
  List,
  ListItem,
  ListItemText,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';

// 静的ページの文章を組み立てる小部品。
// 各ページでTypographyのvariant/余白を書き分けずに済ませ、見出し階層とリズムを揃える。
// 箇条書き・定義表は「配列を渡す」でなく「子要素で並べる」APIにしている:
// リンク等のJSXを含む項目を配列で渡すとreact/jsx-keyの対象になり、各項目にkeyを書く手間が要るため

export function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section>
      <Typography variant="h6" component="h2" sx={{ mt: 4, mb: 1 }}>
        {title}
      </Typography>
      {children}
    </section>
  );
}

export function SubSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <>
      <Typography
        variant="subtitle1"
        component="h3"
        sx={{ mt: 2.5, mb: 0.5, fontWeight: 'bold' }}
      >
        {title}
      </Typography>
      {children}
    </>
  );
}

export function P({ children }: { children: React.ReactNode }) {
  return (
    <Typography variant="body1" component="p" sx={{ mb: 1.5 }}>
      {children}
    </Typography>
  );
}

// 箇条書き: <Bullets><Bullet>…</Bullet>…</Bullets>
export function Bullets({ children }: { children: React.ReactNode }) {
  return (
    <List dense disablePadding sx={{ mb: 1.5, pl: 2, listStyleType: 'disc' }}>
      {children}
    </List>
  );
}

export function Bullet({ children }: { children: React.ReactNode }) {
  return (
    <ListItem disablePadding sx={{ display: 'list-item' }}>
      <ListItemText primary={children} />
    </ListItem>
  );
}

// 多列の表は狭い画面で1列が縦長に潰れるため、最小幅を確保して表の中だけ横スクロールさせる
export const wideTableMinWidth = 600;

// 見出し行つきの表。セルは文字列のみ（JSXを含む行は DefinitionTable を使う）
export function SimpleTable({
  head,
  rows,
}: {
  head: string[];
  rows: string[][];
}) {
  return (
    <TableContainer component={Paper} variant="outlined" sx={{ mb: 2 }}>
      <Table size="small" sx={{ minWidth: wideTableMinWidth }}>
        <TableHead>
          <TableRow>
            {head.map((cell) => (
              <TableCell key={cell} sx={{ fontWeight: 'bold' }}>
                {cell}
              </TableCell>
            ))}
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row, rowIndex) => (
            <TableRow key={rowIndex}>
              {row.map((cell, cellIndex) => (
                <TableCell key={cellIndex}>{cell}</TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}

// 「項目: 内容」の2列表: <DefinitionTable><Definition term="…">…</Definition>…</DefinitionTable>
export function DefinitionTable({ children }: { children: React.ReactNode }) {
  return (
    <TableContainer component={Paper} variant="outlined" sx={{ mb: 2 }}>
      <Table size="small">
        <TableBody>{children}</TableBody>
      </Table>
    </TableContainer>
  );
}

export function Definition({
  term,
  children,
}: {
  term: string;
  children: React.ReactNode;
}) {
  return (
    <TableRow>
      <TableCell
        component="th"
        scope="row"
        sx={{ fontWeight: 'bold', width: '28%' }}
      >
        {term}
      </TableCell>
      <TableCell>{children}</TableCell>
    </TableRow>
  );
}

// 外部リンク。rel を明示する理由は一覧ページの株探リンクと同じ（MUIのLinkは自動付与しない）
export function ExternalLink({
  href,
  children,
}: {
  href: string;
  children: React.ReactNode;
}) {
  return (
    <Link href={href} target="_blank" rel="noopener noreferrer">
      {children}
    </Link>
  );
}

export function InternalLink({
  to,
  children,
}: {
  to: string;
  children: React.ReactNode;
}) {
  return (
    <Link component={RouterLink} to={to}>
      {children}
    </Link>
  );
}
