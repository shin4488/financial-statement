---
name: sync-extension
description: フロントエンド（application/frontend）の変更をブラウザ拡張リポジトリ（financial-statement-chrome-extension）へ同期する手順。フロントエンドに変更を入れたとき・「拡張に反映して」のときに使用する。
---

# ブラウザ拡張への同期

拡張リポジトリ: https://github.com/shin4488/financial-statement-chrome-extension

ローカルの配置場所は環境ごとに異なる。まずこのリポジトリの隣（`../financial-statement-chrome-extension`）を探し、
なければユーザーに場所を確認する（未cloneなら `gh repo clone` する）。
以下のコマンドは見つけたパスを `$EXT` として使う:

```bash
EXT=../financial-statement-chrome-extension  # 実際の配置に合わせて設定する
```

## 同期対象の判定（最初にやる）

拡張と共有しているのは **`src/shared/financialCharts/` だけ**（コピー運用）。

| 変更箇所 | 拡張への反映 |
| --- | --- |
| `application/frontend/src/shared/financialCharts/` | **必要**（下の手順で同期） |
| `application/frontend/src/features/` などその他のフロント変更 | 不要（拡張は独自のpopup UIを持つ） |
| バックエンドのGraphQLスキーマ・`colorRoles`のenum変更 | **必要**（下の「契約変更のとき」参照） |

ドリフト確認:

```bash
diff -r application/frontend/src/shared/financialCharts "$EXT/src/shared/financialCharts"
```

拡張側のprettier整形差分（日本語と英単語の間のスペース・行幅）と、拡張側READMEの「## コピー元」節の追記は許容。それ以外の差分が未反映分。

## 同期手順

1. 拡張リポジトリでブランチを作る（`change/` などのprefix + kebab-case。コミットは英語1行 `add:` / `change:` prefix）
2. ディレクトリごとコピーする（部分コピーはしない）:
   ```bash
   cp application/frontend/src/shared/financialCharts/* "$EXT/src/shared/financialCharts/"
   ```
3. 拡張側READMEに「## コピー元」節（コピー運用の説明）を復元する（コピーで消えるため。内容は拡張側のgit履歴を参照）
4. 拡張側のprettierで整形する: `(cd "$EXT" && npx prettier --write "src/shared/financialCharts/**")`
5. 拡張リポジトリで `yarn lint` / `yarn lint:type` / `yarn test` を通す
6. push → PR作成（マージはユーザーが行う）

## 契約変更のとき（コード同期だけでは済まないケース）

- **`colorRoles.ts`**: バックエンドのenumとの契約点。role追加はバックエンド / Webフロント / 拡張の3点同時変更
- **GraphQLクエリ・スキーマの変更**: 拡張はクエリを `.graphql` ファイルで持ち、codegenは**本番introspection**（investee.info）を参照する。バックエンドの変更が本番デプロイされてから拡張側で `yarn compile` する（順序が逆だと生成が失敗するか、公開済み拡張が壊れる）
- リリースの順序制約・E2Eのヒントは拡張リポジトリのCLAUDE.mdを参照
