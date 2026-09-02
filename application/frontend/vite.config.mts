import { fileURLToPath, URL } from 'node:url';
import react from '@vitejs/plugin-react';
import browserslistToEsbuild from 'browserslist-to-esbuild';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    // docker-composeではnginx(web)がサービス名appfrontの3000番へ転送してくる
    host: true,
    port: 3000,
    strictPort: true,
    allowedHosts: ['appfront'],
  },
  preview: {
    // `yarn preview`（本番ビルドの動作確認）で、nginxと同様に /api をdocker composeのAPI（host側20000番）へ転送する
    port: 4173,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://localhost:20000',
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
  build: {
    // deploy.shがrsyncする成果物ディレクトリと、その中のファイル配置を維持する
    outDir: 'build',
    sourcemap: true,
    // 対象ブラウザはpackage.jsonのbrowserslist（production）で決める
    target: browserslistToEsbuild(),
    rolldownOptions: {
      output: {
        // 第三者ライブラリのライセンス表記（@license / /*! …）はminify後も残す。
        // CRA(terser)はLICENSE.txtに抽出して配布していたが、Viteの既定はminify時に全削除するため明示する
        comments: { legal: true },
        entryFileNames: 'static/js/main.[hash].js',
        chunkFileNames: 'static/js/[name].[hash].js',
        assetFileNames: ({ names }) =>
          names[0]?.endsWith('.css')
            ? 'static/css/main.[hash][extname]'
            : 'static/media/[name].[hash][extname]',
      },
    },
  },
  test: {
    // 共有チャートキット(shared/financialCharts)のテストはChrome拡張側(jest)と同じ書き方を保つため、
    // describe/it/expectをimportせずグローバルで使う
    globals: true,
    environment: 'jsdom',
  },
});
