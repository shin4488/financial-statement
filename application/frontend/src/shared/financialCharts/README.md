# financialCharts — 共有チャートキット

`financialReports` GraphQL APIが返すチャート構造（StackChart / WaterfallChart）を
そのまま描画する汎用コンポーネント群。**科目・会計基準・表示形式の知識を一切持たない**。

## 共有の前提（このディレクトリの規約）

Webフロントとブラウザ拡張（financial-statement-chrome-extension）で同一実装を使う想定のため:

- import してよいのは `react` と `recharts` のみ（両リポジトリ共通の依存。`*.test.ts` はグローバルの `describe` / `it` / `expect` だけを使い、`jest.*` / `vi.*` などランナー固有のAPIは使わない（コピー先のjestでも動かすため））
- アプリ固有のもの（GraphQLクライアント・codegen生成型・ルーティング・状態管理・
  パスエイリアス `@/`）に依存しない。ディレクトリ内は相対importのみ
- 型は `types.ts` の構造的型で受ける。codegen生成型はフィールド構造が一致するため
  変換なしでそのまま渡せる
- スタイルはコンポーネント内で完結させる（外部CSSを要求しない）。例外は中央寄せの
  `.bar-container` クラスだけで、コピー先のアプリ側CSSにも同じ定義が必要

## 拡張側への展開手順（コピー運用のドリフト対策）

1. このディレクトリをそのままコピーする。ドリフトの確認はコピー元ディレクトリとのdiffで行う
   （コピー先のprettier整形差分と、コピー先READMEの固有追記は許容）
2. 特に `colorRoles.ts` はバックエンドのenumと同時に変更される契約点なので、
   バックエンド側でroleを追加したら両リポジトリへ同時に反映する
   （未知roleは `colorForRole` がグレー表示 + console.warnで検知できる）
3. コピー先が2箇所を超える・更新頻度が上がってきたら、パッケージ化（npm公開 or
   GitHubリポジトリ直接参照）での共有へ移行する
   （git submodule方式は運用の二度手間が大きく本体リポジトリでも廃止した経緯があるため採らない）

## 契約のポイント

- `renderable: false` は正常系（未対応形式・データ欠落）。`note` を代替表示する
- StackChartの `Segment` は `amount` が描画高さ（常に0以上）、`signedAmount` が実値（ツールチップ用）。
  WaterfallChartの `WaterfallStep.amount` は符号付きの実値（増減の向きそのものが情報のため）
- 金額の表示は `formatAmount`（百万円単位・百万円未満切捨て。百万円未満の値は千円単位）に統一する。APIの金額は円のまま
- `colorRole` は意味ベースの色の役割名。新しいroleが増えたときだけ `colorRoles.ts` に1行追加する。
  ウォーターフォールもAPIが `WaterfallStep.colorRole`（cashIncrease / cashDecrease）で指定する。
  フィールドを取得しない古い呼び出し元では符号から同じroleを補う（後方互換）
- セグメントの並び順・ラベルはAPIの配列順序が契約。フロントで並べ替え・翻訳をしない
- `Segment.tooltipLabel` はツールチップ専用の表示名（補足つきの名前）。無ければ `label` を表示する
