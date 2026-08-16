import { useEffect } from 'react';
import { siteOrigin } from './siteRoutes';

// 静的ページの表示中だけ <title> / description / canonical を差し替え、
// ページを離れたら index.html に書かれたトップページ用の値へ戻す。
// 戻す仕組みにしている理由: 一覧ページ側に「自分のメタ情報を再設定する」コードを
// 足さずに済ませるため（一覧ページはindex.htmlの値がそのまま正）。
// react-helmet等を入れない理由: 対象が数ページ・3タグだけで依存を増やすほどではないため
interface PageMeta {
  title: string;
  description: string;
  path: string; // siteRoutesの値。canonicalは siteOrigin + path
}

interface HeadValues {
  title: string;
  description: string;
  canonical: string;
}

// index.html由来の値。最初にフックが動いたときに1度だけ退避する
let defaults: HeadValues | null = null;

const descriptionMeta = () =>
  document.head.querySelector<HTMLMetaElement>('meta[name="description"]');
const canonicalLink = () =>
  document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]');

function readHead(): HeadValues {
  return {
    title: document.title,
    description: descriptionMeta()?.content ?? '',
    canonical: canonicalLink()?.href ?? '',
  };
}

function writeHead(values: HeadValues) {
  document.title = values.title;
  const description = descriptionMeta();
  if (description) {
    description.content = values.description;
  }
  const canonical = canonicalLink();
  if (canonical) {
    canonical.href = values.canonical;
  }
}

export function usePageMeta({ title, description, path }: PageMeta) {
  useEffect(() => {
    if (!defaults) {
      defaults = readHead();
    }
    const restoreTo = defaults;
    writeHead({ title, description, canonical: `${siteOrigin}${path}` });
    return () => writeHead(restoreTo);
  }, [title, description, path]);
}
