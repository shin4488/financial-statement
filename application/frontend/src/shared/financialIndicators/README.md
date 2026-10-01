# financialIndicators — ROE・ROA の共有表示

Web 版とブラウザ拡張が同じ表示を使うためのコンポーネント。API が返す値・状態・出所をそのまま表示し、比率の計算や欠損の補完をしない。

- 依存は両アプリにある React・MUI のみ。アプリ固有の生成型・状態管理・パスエイリアスに依存しない。
- 構造的型を `types.ts` に定義し、両アプリの GraphQL 生成型を変換せずに渡す。
- 旧バージョンの拡張キャッシュ等で指標全体がない場合は「データなし」を表示する。0 と負数は有効値として扱う。
- 企業公表 ROE には出所と計算条件のツールチップを表示する。ROA の財務レバレッジ欄だけが対象外。
- テストは Testing Library と共通のテスト API を使い、Jest/Vitest 固有 API に依存しない。

## 同期

コピー元は financial-statement の `application/frontend/src/shared/financialIndicators/`。変更はコピー元に入れ、ディレクトリ全体を拡張の `src/shared/financialIndicators/` に同期する。拡張側の Prettier 整形差分だけを許容する。

Web・拡張ともに、指標を上寄せ・高さ 300px・上余白 8px で表示する。
