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

// index.html由来の「戻し先」。モジュール読込時（Reactの描画前）に退避する。
// 初回フック実行まで退避を遅らせると、その時点でheadが既に書き換わっていた場合に
// 誤った値を戻し先として覚えてしまうため
const defaults = readHead();

// 使用中のページ数。ルーティング上このフックを使うページは同時に1つだが、
// 万一重なっても「最後の1つが外れたときだけindex.htmlへ戻す」に収まるようにする
// （数えないと、先に外れた側のクリーンアップが表示中のページのメタ情報を戻してしまう）
let activeCount = 0;

export function usePageMeta({ title, description, path }: PageMeta) {
  useEffect(() => {
    activeCount += 1;
    writeHead({ title, description, canonical: `${siteOrigin}${path}` });
    return () => {
      activeCount -= 1;
      if (activeCount === 0) {
        writeHead(defaults);
      }
    };
  }, [title, description, path]);
}
