# financialCharts — 共有チャートキット

`financialReports` GraphQL API が返すチャート構造（StackChart / WaterfallChart / FreeCashFlowTrend）を
そのまま描画する汎用コンポーネント群。BS・PL・CF では科目や会計基準を解釈せず、
フリー CF も API が返した各年の値を描画する。

## コピー元

- financial-statement `application/frontend` の `src/shared/financialCharts/`

このディレクトリはコピー運用。修正はコピー元（Web フロント側）に入れてから展開すること。
ドリフトの確認はコピー元ディレクトリとの diff で行う（コピー先の prettier 整形による差分は許容）。

## 共有の前提（このディレクトリの規約）

Web フロントとブラウザ拡張（financial-statement-chrome-extension）で同一実装を使う想定のため:

- UI の依存は、両リポジトリで既に使う `react`・`recharts`・`@mui/material` に限定する。
  MUI は Web 側の v5 と拡張側の v6 の両方で使える API を選び、両側で型・テスト・描画を確認する。
  `*.test.ts` はグローバルの `describe` / `it` / `expect` だけを使い、`jest.*` / `vi.*` などランナー固有の API は使わない（コピー先の jest でも動かすため）
- アプリ固有のもの（GraphQL クライアント・codegen 生成型・ルーティング・状態管理・
  パスエイリアス `@/`）に依存しない。ディレクトリ内は相対 import のみ
- 型は `types.ts` の構造的型で受ける。codegen 生成型はフィールド構造が一致するため
  変換なしでそのまま渡せる
- レイアウトは MUI の `Box`・`Stack`・`Typography` を使い、コンポーネント内で完結させる。
  アプリ側の外部 CSS を要求しない。MUI の余白指定を基本とし、従来の寸法が必要な箇所は px 値を明示する

## 拡張側への展開手順（コピー運用のドリフト対策）

1. このディレクトリをそのままコピーする。ドリフトの確認はコピー元ディレクトリとの diff で行う
   （コピー先の prettier 整形差分と、コピー先 README の固有追記は許容）
2. 特に `colorRoles.ts` はバックエンドの enum と同時に変更される契約点なので、
   バックエンド側で role を追加したら両リポジトリへ同時に反映する
   （未知 role は `colorForRole` がグレー表示 + console.warn で検知できる）
3. コピー先が 2 箇所を超える・更新頻度が上がってきたら、パッケージ化（npm 公開 or
   GitHub リポジトリ直接参照）での共有へ移行する
   （git submodule 方式は運用の二度手間が大きく本体リポジトリでも廃止した経緯があるため採らない）

## 契約のポイント

- `renderable: false` は正常系（未対応形式・データ欠落）。`note` を代替表示する
- StackChart の `Segment` は `amount` が描画高さ（常に 0 以上）、`signedAmount` が実値（ツールチップ用）。
  WaterfallChart の `WaterfallStep.amount` は符号付きの実値（増減の向きそのものが情報のため）
- FreeCashFlowTrend の金額は円で受け取り、カードには百万円単位で表示する。欠損年は `amount: null` として区別する
- BS・PL の金額は `formatAmount`（百万円単位・百万円未満切捨て。百万円未満の値は千円単位）で表示する。CF はグラフ外に「百万円」を置き、`formatAmountInMillions` でバー上の数値とツールチップを百万円単位に揃える。API の金額は円のまま
- `colorRole` は意味ベースの色の役割名。新しい role が増えたときだけ `colorRoles.ts` に 1 行追加する。
  ウォーターフォールも API が `WaterfallStep.colorRole`（cashIncrease / cashDecrease）で指定する。
  フィールドを取得しない古い呼び出し元では符号から同じ role を補う（後方互換）
- セグメントの並び順・ラベルは API の配列順序が契約。フロントで並べ替え・翻訳をしない
- `Segment.tooltipLabel` はツールチップ専用の表示名（補足つきの名前）。無ければ `label` を表示する
- BS・PL の区画内ラベルは Recharts の文字サイズ・折り返しを保ち、区画に上下左右 2px の余裕を持って収まる場合だけ表示する。全科目の符号付き金額と割合はツールチップで確認できる（`ratio: null` は割合なし）
