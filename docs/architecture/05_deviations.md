# 設計ドキュメント（docs/zero-base-redesign）からの変更点

実装時に判明した事情による変更。**3層構造・縦持ち・チャート契約という骨格は設計どおり。**

| # | 設計ドキュメント | 実装 | 理由 |
|---|---|---|---|
| 1 | モデルはトップレベル（`Company` / `FinancialStatement` 等） | `Disclosure::` 名前空間（`Disclosure::FinancialStatement` 等） | Railsアプリのモジュール名が `FinancialStatement` のため同名トップレベルクラスは定義不可（TypeError）。旧 `Company` モデルとの衝突も回避 |
| 2 | 旧テーブルを `legacy_*` にリネームして共存（方式A） | **完全追加型**: 新規3テーブルのみ追加し、`companies` は既存テーブルを共用（新モデルがカラム名をaliasで吸収） | 「既存プログラムに影響を与えない」を最優先。リネームは既存モデル2ファイルの変更が必要になる |
| 3 | `query_type.rb` を置き換え（旧クエリ削除） | 旧クエリと**同居**。新クエリはResolverクラスに切り出し、既存ファイルへの変更は `field` 1行 | 同上。切替判断まで新旧両方が動く |
| 4 | 金額は `GraphQL::Types::BigInt` | 独自スカラ `Money`（JSON数値のまま返す） | ①gem実装は文字列でシリアライズされ、全クライアント（Web+Chrome拡張）に変換実装が必要になる ②スキーマ名 `BigInt` は既存クエリの型が使用済みで衝突する。円の最大値(4e14)はJSの安全整数域(9e15)内 |
| 5 | CF符号の enum `NumberSign` | `CashFlowSign`（新設） | スキーマ名 `NumberSign` は既存クエリの型が使用済みで衝突する |
| 6 | `structs.rb` に Struct群を定義 | `app/services/charts.rb`（名前空間ファイル）に定義 | Zeitwerkは「1ファイル=1定数」を要求し `Charts::Structs` の定義を期待してエラーになる |
| 7 | sidekiq-cron を新ジョブに差し替え | **cron未登録**（ジョブ・rakeタスクのみ追加） | 旧ジョブと並走するとEDINETへのリクエストが倍増する。切替は明示的な判断のタイミングで行う |
| 8 | `Reports::SearchQuery` | `Disclosure::SearchQuery` | モデルと同じドメイン名前空間に揃える（`Reports` と `Reporting` のような紛らわしい併存を避ける） |
| 9 | フロントは既存 `src/` を置き換え・トップページを新UI化 | `/v2` ルートに新UIを追加（既存 `/` は無変更）。見た目は既存と同一（MUI+カルーセル+同配色） | 既存無変更の制約 + 新旧を見比べて切替判断できる |
| 10 | Redux削除・素朴なHTMLフォームUI | 検索条件はURLクエリ（設計どおり）だが、UIは既存と同じMUI AppBar構成。カルーセル自動切替のみ既存Reduxスライスを共有 | 見た目・操作感を既存ページと揃えるため |
| 11 | チャートコンポーネントは feature 配下 | **`src/shared/financialCharts/` に分離**（アプリ非依存の共有キット） | Chrome拡張リポジトリと同一実装を共有するため（コピー/将来のpackage化を想定した依存規約付き） |
| 12 | CFステップのラベルは正式名称 | 短縮形（期首残/営業CF/投資CF/財務CF/期末残） | X軸目盛りにそのまま表示され、正式名称では潰れて読めない（既存ページと同じ表記） |
| 13 | ratioは `truncate(3) * 100` | `(BigDecimalで*100まで計算).truncate(1)` | float化してから掛けると `19.900000000000002%` がAPIに乗る |
| 14 | database.yml testブロックは既定のまま | testブロックにENV接続情報を追記 | test環境がDB接続情報を持っておらずRSpecが実行不能だった（既存挙動には影響なし） |
| 15 | 企業名は `companies` のみ | `reports.company_name_ja/en` にも提出時点の名前を保存し、APIはこちらを優先表示。マスタは最新会計期の有報からのみ更新 | 社名変更した企業の過去年度を当時の名前で表示するため。バックフィルでマスタが古い社名に巻き戻るのも防ぐ |

## 検証結果（2026-08-02 実施）

| 検証 | 結果 |
|---|---|
| RSpec（61 examples: Builder/Extractor/取込/検索/GraphQL/整合性） | 全て成功 |
| 実XBRL 6社（武田・三菱商事・NTT・楽天・東京海上・三菱UFJ）取込 | 全社、実測表の値と一致（NTTのサマリフォールバック・東京海上のPL表示不可を含む） |
| GraphQL `financialReports`（curl） | チャート構造・数値型・比率が設計どおり。既存 `companyFinancialStatements` も同時に動作 |
| ブラウザ `/v2`（docker compose環境） | 4形式のBS/PL/CF・表示不可の代替表示・既存と同一の見た目を確認 |
| フロント型チェック・ESLint | `tsc --noEmit` 0件・webpack compiled successfully |
