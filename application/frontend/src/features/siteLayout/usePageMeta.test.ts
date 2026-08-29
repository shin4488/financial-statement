import { renderHook } from '@testing-library/react';
import { siteOrigin } from './siteRoutes';

// 戻し先（index.htmlの値）はモジュール読込時に退避されるため、先にheadを整えてから読み込む
let usePageMeta: typeof import('./usePageMeta').usePageMeta;
beforeAll(() => {
  document.title = 'デフォルトタイトル';
  document.head.insertAdjacentHTML(
    'beforeend',
    '<meta name="description" content="デフォルト説明" /><link rel="canonical" href="https://example.com/" />',
  );
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  ({ usePageMeta } = require('./usePageMeta'));
});

const currentHead = () => ({
  title: document.title,
  description: document.head.querySelector<HTMLMetaElement>(
    'meta[name="description"]',
  )?.content,
  canonical: document.head.querySelector<HTMLLinkElement>(
    'link[rel="canonical"]',
  )?.href,
});

describe('usePageMeta', () => {
  it('表示中はページの値に差し替え、外れたらindex.htmlの値へ戻す', () => {
    const { unmount } = renderHook(() =>
      usePageMeta({
        title: 'このページ',
        description: '説明文',
        path: '/about',
      }),
    );
    expect(currentHead()).toEqual({
      title: 'このページ',
      description: '説明文',
      canonical: `${siteOrigin}/about`,
    });

    unmount();
    expect(currentHead()).toEqual({
      title: 'デフォルトタイトル',
      description: 'デフォルト説明',
      canonical: 'https://example.com/',
    });
  });

  it('ページが重なっても、先に外れた側が表示中のメタ情報を戻さない', () => {
    const first = renderHook(() =>
      usePageMeta({ title: '先のページ', description: 'a', path: '/guide' }),
    );
    const second = renderHook(() =>
      usePageMeta({ title: '後のページ', description: 'b', path: '/contact' }),
    );
    expect(document.title).toBe('後のページ');

    first.unmount(); // 表示中（後のページ）の値は保たれる
    expect(document.title).toBe('後のページ');

    second.unmount(); // 全て外れたときだけ戻す
    expect(document.title).toBe('デフォルトタイトル');
  });
});
