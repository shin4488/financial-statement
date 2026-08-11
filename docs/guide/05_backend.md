# 05. バックエンド実装

`application/backend`（Rails）の実装ガイド。[04章](04_system_overview.md)の地図を
実際のクラスとファイルに対応づける。設計の「なぜ」は
[docs/architecture/](../architecture/README.md)（00〜03）が正で、ここでは重複させない。

## ディレクトリマップ

| パス（application/backend/ 以下） | 内容 |
|---|---|
| `app/jobs/daily_ingestion_job.rb` | 日次バッチの入口（中身はServiceを呼ぶ1行） |
| `app/services/ingestion/` | 取込パイプライン一式（Service・Extractor・形式判定） |
| `app/lib/edinet/client.rb` | EDINET APIとの通信（外部I/Oはここに集約） |
| `app/lib/xbrl/document.rb` | XBRLパーサ |
| `app/lib/financial_statements/item_codes.rb` | 科目コード全40種の唯一の定義 |
| `app/models/disclosure/` | ActiveRecordモデル（Company / Report / FinancialStatement / FinancialStatementItem） |
| `app/services/charts/` | チャート組み立て（BuilderRegistry・各Builder） |
| `app/services/disclosure/search_query.rb` | 一覧検索クエリ |
| `app/graphql/` | GraphQLスキーマ・型・リゾルバ |
| `config/sidekiq-cron.yml` | 日次ジョブのスケジュール定義（毎日2:00） |
| `lib/tasks/ingestion.rake` | 手動取込タスク（backfill / documents） |
| `spec/` | RSpecテスト |

## 取込パイプライン

### 登場するクラスと責務

| クラス | 責務 |
|---|---|
| `DailyIngestionJob` | sidekiq-cronから毎日2:00に起動される。`Ingestion::DailyIngestionService.run` を呼ぶだけ |
| `Ingestion::DailyIngestionService` | 日付ループと失敗の隔離。既定の対象は**前日**提出分 |
| `Edinet::Client` | 書類一覧の取得（有報120・訂正有報130のみ、証券コードなし=非上場は除外）とXBRLダウンロード |
| `Xbrl::Document` | XBRLをパースし、fact（タグ+コンテキスト→値）の辞書を作る |
| `Ingestion::DeiExtractor` | DEI（書類メタ情報）の読み取り。会計基準・EDINETコード・連結有無・会計期間など |
| `Ingestion::FormatDetector` / `FormatRegistry` | 形式判定（[04章](04_system_overview.md)のフロー）と、形式→Extractorの対応表 |
| `Ingestion::Extractors::*` | 形式ごとのタグ→科目コードのマッピング（後述） |
| `Ingestion::ReportIngester` | 全体の指揮とDB保存。**1有報 = 1トランザクション** |

### 信頼性の仕組み

- **逐次実行 + 1秒スリープ**: EDINET APIの403対策。並列化してはいけない
- **失敗の隔離が2段**: 書類単位の失敗はログ+Sentry通知して次の書類へ、
  日単位（一覧取得の失敗）も同様に次の日へ進む
- **自動リトライなし**: 代わりに全処理が冪等で、同じrakeタスクの再実行が唯一かつ安全な
  リカバリ手段（手順は[08章](08_operations.md)）
- **取り込まない判断**: DEIの会計基準が未知・EDINETコードが不正・一覧APIとDEIの
  証券コードが不一致の場合は保存せずSentryへ通知する（他社データの上書き事故を防ぐ）

### 保存時の防御（`ReportIngester#persist`）

| 防御 | 目的 |
|---|---|
| 企業マスタの社名更新は最新年度の取込時のみ | 過去年度のバックフィルで社名が古いものに巻き戻らない |
| 科目が空で既存データがあるならスキップ | 財務factを含まない訂正有報が正しいデータを空で潰さない |
| 科目は削除→一括挿入で総入れ替え | 「行がない=開示なし」の規約を保つ（訂正で消えた科目は消える必要がある） |
| 連結がなくなった有報では旧連結行を削除 | 連結廃止時に古い表示用データが残らない |

## XBRLパーサ（`Xbrl::Document`）

- パーサはNokogiri。ファイルを1回だけ走査して `(名前空間, タグ名, コンテキスト) → 値` の
  ハッシュを作り、以降の参照をO(1)にする
- 読む名前空間は[01章](01_financial_knowledge.md)の4つだけ。企業拡張タグはここで弾かれる
- 金額の変換は「数値として不正なら`nil`」（`to_i` だと文字列が0円になり
  「開示なし」と「0円」の区別が壊れるため）。bigintの範囲外も`nil`
- zipとその中身に500MBのサイズ上限を設け、展開後のファイルは処理後すぐ削除する

## Extractor（タグ→科目コード）

Extractorは実質「マッピング定数」で、ロジックをほぼ持たない。1科目に複数タグを
並べると先頭から順に探すフォールバックになる（順序に意味があるので入れ替えない）。

| Extractor | 名前空間 | 特徴 |
|---|---|---|
| `JgaapGeneral` | `jppfs_cor` | 売上は4段・売上原価は8段のフォールバック（業種でタグが違うため） |
| `JgaapBank` | `jppfs_cor` | 貸出金・預金など銀行専用タグ。**経常収益は `OrdinaryIncomeBNK`、経常利益は `OrdinaryIncome`**。似た名前で桁が兆単位で違うため取り違えに注意 |
| `IfrsClassified` | `jpigp_cor` | 非流動負債はタクソノミ公式のタイポ（`NonCurrentLabilitiesIFRS`）を先に引く。売上の最終フォールバックは経営指標サマリのタグ |
| `IfrsLiquidity` | `jpigp_cor` | BSは合計系のみ。PL/CFのマッピングは`IfrsClassified`と定数を共有（継承はしない方針） |

- 営業CFなどのタグは日本基準が `...InvestmentActivities`、IFRSが `...InvestingActivitiesIFRS` と
  微妙に異なる
- CFの期首残高だけは前期末時点（`Prior1YearInstant`）のコンテキストで取る
- タグと科目コードの完全な対応表は [docs/architecture/05_taxonomy_mapping.md](../architecture/05_taxonomy_mapping.md)、
  6社の実測データは [docs/architecture/06_xbrl_research.md](../architecture/06_xbrl_research.md)
  （**XBRLタグを触る作業の前に必読**）

## チャート生成（`Charts::`）

参照系の中心。科目コードの辞書からチャート構造を組み立てる。

### BuilderRegistry

| 形式 | BS | PL | CF |
|---|---|---|---|
| `jgaap_general` | `BsJgaapGeneral` | `PlJgaapGeneral` | 全形式共通の `CashFlow` |
| `jgaap_bank` | `BsJgaapBank` | `PlJgaapBank` | 同上 |
| `ifrs_classified` | `BsIfrsClassified` | `PlIfrs` | 同上 |
| `ifrs_liquidity` | `BsIfrsLiquidity` | `PlIfrs`（PLはBS様式に依存しないため共通） | 同上 |
| `unsupported` | 登録なし → 「表示に対応していません」の説明文つきで `renderable: false` を返す | 同左 | 同上 |

### 共通の仕掛け（`StackBase`）

- 比率はBigDecimalで計算して小数1桁に切り捨て（浮動小数の誤差で「19.900000000000002%」や
  合計100%超になるのを防ぐ）
- セグメントの `amount` は絶対値（rechartsに負値を渡すと逆向きに描かれる）、
  実際の符号つき金額は `signedAmount` に分けて持つ
- 借方合計と貸方合計の乖離が**1割**を超えたら `renderable: false`
- 債務超過は3本目のバーを作り、透明な`spacer`セグメントで高さを合わせた上に
  マイナスの純資産を描く

### Builderごとの要点

- 銀行BSの「その他資産」「その他負債」、IFRS流動性配列BSの「その他資産」、IFRS PLの
  「その他損益（純額）」は、開示された合計からの**残差**として導出する
  （こうすることで借方=貸方が定義的に成立する）
- 各Builderは必須科目が欠けたら `renderable: false` を返す。銀行BSは預金がなければ
  描かない（「預金0%の銀行」という誤ったグラフを避ける）
- CFは期首残・営業・投資・財務・期末残の**5点すべて揃わなければ描かない**（all-or-nothing）

実例（武田薬品のPL残差・三菱UFJのBS残差など）は
[docs/architecture/03_serving.md](../architecture/03_serving.md) にある。

## GraphQL API

- エンドポイントは `POST /graphql` の1本のみ（開発環境でのみGraphiQLが `/graphiql` に立つ）。
  認証はなく、クエリも `financialReports` の1フィールドだけ
- 未認証・公開である前提の防御: `limit` 1〜100、`stockCodes` 最大100件、
  `max_complexity 400`・`max_depth 20`、さらに `limit` の値がコストに反映される
  カスタムcomplexity計算
- 金額は独自スカラ `Money`（数値のまま返す）。標準のBigIntは文字列になるため使わない。
  日本企業の最大級の総資産（400兆円=4×10^14）はJavaScriptの安全整数（9×10^15）に収まる
- `SearchQuery` は提出日降順で並べ、証券コードは4桁+`0`の5桁に変換して照合、
  CFパターンは科目行の符号をEXISTSサブクエリで判定する
- スキーマは `rake graphql:dump_schema` で `schema.graphql` に書き出してコミットする運用

レスポンス構造（チャート契約）の詳細は [docs/architecture/03_serving.md](../architecture/03_serving.md) が正。

## テスト

- RSpec。`spec/` に14ファイル。チャートBuilderはDB不要の純関数テスト、
  取込は実企業のXBRLをfixtureにした実データテスト
- 実XBRL（6社+2社）は1件数MBあるためgit管理外。手元にない場合そのテストはskipされる。
  取得手順は `spec/fixtures/xbrl/README.md`
- `mapping_consistency_spec` が「全Extractorのマッピングキー ⊆ 科目コード定義」を検証し、
  バリデーションを通らない一括挿入の正当性を担保している

## 環境変数

figaro形式で `config/application.yml`（gitignore済み）に置く。定義すべきキーは
`config/application.yml.sample` にあり、**このファイルには実値を書かないルール**
（プレースホルダとローカルdocker用デフォルトのみ可）。

| キー | 用途 |
|---|---|
| `EDINET_API_KEY` | EDINET APIキー（必須） |
| `POSTGRES_*`（5種） | DB接続情報（docker開発ではDockerfileの既定値で足りる） |
| `REDIS_HOST_NAME` / `REDIS_PORT` / `REDIS_PASSWORD` | Sidekiq用Redis接続 |
| `SENTRY_DSN` | エラー監視（未設定なら通知無効） |
| `SERVER_HOST_NAME` | 本番のみ。DNSリバインディング対策の許可ホスト名 |
| `SECRET_KEY_BASE` | 本番のみ |

---

次章: [06. フロントエンド実装](06_frontend.md)
