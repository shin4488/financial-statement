# financialCharts — 共有チャートキット

`financialReports` GraphQL APIが返すチャート構造（StackChart / WaterfallChart）を
そのまま描画する汎用コンポーネント群。**科目・会計基準・表示形式の知識を一切持たない**。

## 共有の前提（このディレクトリの規約）

Webフロントとブラウザ拡張（financial-statement-chrome-extension）で同一実装を使う想定のため:

- import してよいのは `react` と `recharts` のみ（両リポジトリ共通の依存）
- アプリ固有のもの（GraphQLクライアント・codegen生成型・ルーティング・状態管理・
  パスエイリアス `@/`）に依存しない。ディレクトリ内は相対importのみ
- 型は `types.ts` の構造的型で受ける。codegen生成型はフィールド構造が一致するため
  変換なしでそのまま渡せる
- スタイルはコンポーネント内で完結させる（外部CSSを要求しない）

## 拡張側への展開手順（コピー運用のドリフト対策）

1. このディレクトリをそのままコピーする。ドリフトの確認はコピー元ディレクトリとのdiffで行う
   （コピー先のprettier整形差分と、コピー先READMEの固有追記は許容）
2. 特に `colorRoles.ts` はバックエンドのenumと同時に変更される契約点なので、
   バックエンド側でroleを追加したら両リポジトリへ同時に反映する
   （未知roleは `colorForRole` がグレー表示 + console.warnで検知できる）
3. コピー先が2箇所を超える・更新頻度が上がってきたら、親リポジトリで実績のある
   git submodule 方式（このディレクトリを共有用の小リポジトリに切り出し）へ移行する

## 契約のポイント

- `renderable: false` は正常系（未対応形式・データ欠落）。`note` を代替表示する
- `amount` は描画高さ（常に0以上）、`signedAmount` が実値（ツールチップ用）
- `colorRole` は意味ベースの色enum。新しいroleが増えたときだけ `colorRoles.ts` に1行追加する
- セグメントの並び順・ラベルはAPIの配列順序が契約。フロントで並べ替え・翻訳をしない
