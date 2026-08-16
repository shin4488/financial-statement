// サイト全体で共有するURL定義。
// フッターのリンク・App.tsxのルート定義・各ページのcanonicalが同じ値を参照する。
// public/sitemap.xml は静的ファイルのため自動では追従しない: パスを変えたら手で合わせること
export const siteOrigin = 'https://investee.info';

export const siteRoutes = {
  top: '/',
  about: '/about',
  guide: '/guide',
  privacy: '/privacy',
  contact: '/contact',
} as const;

// フッターに並べる順（サイト説明 → 使い方 → 規約系 → 連絡先）
export const footerLinks: { to: string; label: string }[] = [
  { to: siteRoutes.about, label: 'このサイトについて' },
  { to: siteRoutes.guide, label: '財務三表の読み方' },
  { to: siteRoutes.privacy, label: 'プライバシーポリシー' },
  { to: siteRoutes.contact, label: 'お問い合わせ' },
];
