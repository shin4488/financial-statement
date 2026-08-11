# 05. バックエンド実装

`application/backend`（Rails）の実装ガイド。[04章](04_system_overview.md)の地図を
実際のクラスとファイルに対応づける。設計の「なぜ」は[08章](08_layering.md)、
取込・表示それぞれの詳細と実データでの実例は[10章](10_ingestion.md)・[11章](11_serving.md)にあり、
ここでは重複させない。

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

### クラスと責務

[04章](04_system_overview.md)のシーケンス図に登場する処理の実体は次のクラス。

| クラス | 責務 |
|---|---|
| `DailyIngestionJob` | sidekiq-cronから毎日2:00に起動。`Ingestion::DailyIngestionService.run` を呼ぶだけ |
| `Ingestion::DailyIngestionService` | 日付ループと失敗の隔離。既定の対象は**前日**提出分 |
| `Edinet::Client` | 書類一覧の取得とXBRLダウンロード |
| `Xbrl::Document` | XBRLをパースし、fact（タグ+コンテキスト→値）の辞書を作る |
| `Ingestion::DeiExtractor` | DEI（書類メタ情報）の読み取り |
| `Ingestion::FormatDetector` / `FormatRegistry` | 形式判定と、形式→Extractorの対応表 |
| `Ingestion::Extractors::*` | 形式ごとのタグ→科目コードのマッピング |
| `Ingestion::ReportIngester` | 全体の指揮とDB保存。**1有報 = 1トランザクション** |

### 具体例: ある日のバッチで4件の書類が来たら

信頼性の仕組み（逐次実行・失敗の隔離・冪等・取り込まない判断）は、
具体的な1日の動きで見るとわかりやすい。

| 書類 | 内容 | 何が起きるか |
|---|---|---|
| A | 通常の有報 | 保存される。1秒待って次へ |
| B | Aと同じ企業・同じ会計期間の訂正有報 | 新規追加ではなく**同じ行への上書き**になる（有報の自然キーが「企業+会計期間」のため） |
| C | パース中に例外が発生 | ログ+Sentry通知して**次の書類へ進む**（Cだけが未取込になり、他は無事） |
| D | DEIの証券コードが一覧APIと不一致 | **保存せず**Sentryへ通知（他社レコードの上書き事故を防ぐ） |

- 翌日、通知に気づいたら `rake 'ingestion:documents[Cの書類ID]'` で再取込する。
  全処理が冪等（何度実行しても同じ結果）なので、A・Bごと再実行しても壊れない
- 自動リトライは持たない。冪等な再実行が唯一のリカバリ手段（手順は[07章](07_development_operations.md)）
- 書類間の1秒待ちと逐次実行はEDINET APIの403対策。**並列化してはいけない**

### 保存時の防御（`ReportIngester#persist`）

| 防御 | 目的 |
|---|---|
| 企業マスタの社名更新は最新年度の取込時のみ | 過去年度のバックフィルで社名が古いものに巻き戻らない |
| 科目が空で既存データがあるならスキップ | 財務factを含まない訂正有報が正しいデータを空で潰さない |
| 科目は削除→一括挿入で総入れ替え | 「行がない=開示なし」の規約を保つ（訂正で消えた科目は消える必要がある） |
| 連結がなくなった有報では旧連結行を削除 | 連結廃止時に古い表示用データが残らない |

## XBRLパーサ（`Xbrl::Document`）

XBRLファイルを1回だけ走査して「タグ+コンテキスト → 値」の辞書を作り、
以降の取り出しを高速にする。データの姿はこう変わる。

```
① XBRLの中の1つのfact（XML）
   <jppfs_cor:Assets contextRef="CurrentYearInstant" ...>100000000</jppfs_cor:Assets>

② Xbrl::Documentが持つ辞書
   { ["jppfs_cor", "Assets", "CurrentYearInstant"] => "100000000" }

③ 取り出し（Extractorから呼ばれる）
   xbrl.money("jppfs_cor:Assets", "CurrentYearInstant")  #=> 100000000
```

| 仕組み | 内容 |
|---|---|
| 名前空間フィルタ | [01章](01_financial_knowledge.md)の4名前空間だけ読む。企業拡張タグは②の時点で弾かれる |
| 金額変換 | 数値として不正なら`nil`（`to_i`だと文字列が0円になり「開示なし」と「0円」の区別が壊れる）。bigint範囲外も`nil` |
| サイズ上限 | zipとその中身に500MBの上限。展開したファイルは処理後すぐ削除 |

## Extractor（タグ→科目コード）

Extractorは実質「マッピング定数」で、ロジックをほぼ持たない。
1科目に複数タグを並べると、**先頭から順に探すフォールバック**になる。

```ruby
# JgaapGeneralの売上マッピング（4段フォールバック。順序が優先度）
"pl.revenue" => %w[
  jppfs_cor:OperatingRevenue1    # 営業収益
  jppfs_cor:NetSales             # 売上高（最も一般的）
  jppfs_cor:ContractsCompletedRevOA                      # 完成工事高
  jppfs_cor:NetSalesOfCompletedConstructionContractsCNS  # 完成工事高（建設業）
]
# 建設業の有報にはNetSalesのfactがない → 3〜4番目で初めて値が取れ、
# それが pl.revenue として保存される（業種ごとの科目名のゆれをここで吸収する）
```

| Extractor | 名前空間 | 特徴 |
|---|---|---|
| `JgaapGeneral` | `jppfs_cor` | 売上4段・売上原価8段のフォールバック |
| `JgaapBank` | `jppfs_cor` | 貸出金・預金など銀行専用タグ。**経常収益は `OrdinaryIncomeBNK`、経常利益は `OrdinaryIncome`**。似た名前で桁が兆単位で違うため取り違えに注意 |
| `IfrsClassified` | `jpigp_cor` | 非流動負債はタクソノミ公式のタイポ（`NonCurrentLabilitiesIFRS`）を先に引く |
| `IfrsLiquidity` | `jpigp_cor` | BSは合計系のみ。PL/CFは`IfrsClassified`と定数を共有（継承はしない方針） |

- CFの期首残高だけは前期末時点（`Prior1YearInstant`）のコンテキストで取る
- タグと科目コードの完全な対応表は[12章](12_taxonomy_mapping.md)、
  6社の実測データは[13章](13_xbrl_research.md)（**XBRLタグを触る作業の前に必読**）

## チャート生成（`Charts::`）

参照系の中心。科目コードの辞書からチャート構造を組み立てる。

### 具体例: 入力と出力

架空の単純な数字でPLチャートを組むと、入出力はこうなる。

```
入力（DBから読んだ科目コード → 金額）
  { "pl.revenue" => 100, "pl.cost_of_sales" => 60, "pl.sga" => 30, "pl.operating_profit" => 10 }

出力（PlJgaapGeneral が組む StackChart）
  bars:
    借方: [ 売上原価 60（60.0%・expense1）,
            販売費及び一般管理費 30（30.0%・expense2）,
            営業利益 10（10.0%・profit） ]
    貸方: [ 売上 100（100.0%・revenue） ]
```

- 借方合計(100) = 貸方合計(100) になる。**2本のバーの高さが揃うことが正しさの検証**
  でもあり、乖離が1割を超えるデータは `renderable: false` にして描かない
- ラベル・積み上げ順・色の役割（`colorRole`）まで全部ここで決める。フロントは並べるだけ
- 実データの例（赤字企業の残差導出・銀行の残差導出・表示不可）は[11章](11_serving.md)にある

### Builderの分担（`BuilderRegistry`）

| 形式 | BS | PL | CF |
|---|---|---|---|
| `jgaap_general` | `BsJgaapGeneral` | `PlJgaapGeneral` | 全形式共通の `CashFlow` |
| `jgaap_bank` | `BsJgaapBank` | `PlJgaapBank` | 同上 |
| `ifrs_classified` | `BsIfrsClassified` | `PlIfrs` | 同上 |
| `ifrs_liquidity` | `BsIfrsLiquidity` | `PlIfrs`（PLはBS様式に依存しないため共通） | 同上 |
| `unsupported` | 登録なし → 説明文つき `renderable: false` | 同左 | 同上 |

形式によらない共通処理は基底クラス `StackBase` に1回だけ書いてある。

| 共通処理 | 内容 |
|---|---|
| 比率計算 | BigDecimalで計算して小数1桁に切り捨て（浮動小数の誤差による「19.900000000000002%」や合計100%超を防ぐ） |
| 負値の扱い | 描画高さ `amount` は絶対値、実額は `signedAmount` に分離（rechartsに負値を渡すと逆向きに描かれる） |
| 債務超過 | 3本目のバーを生成し、透明な`spacer`で高さを合わせた上にマイナスの純資産を描く |
| 貸借検証 | 乖離1割超で `renderable: false`（誤ったグラフより出さない方を選ぶ） |

各Builderの要点は2つだけ押さえれば読める。

- 「その他資産」「その他損益（純額）」などは開示合計からの**残差**として導出する
  （借方=貸方が定義的に成立する）
- 必須科目が欠けたら描かない。銀行BSは預金がなければ描かない（「預金0%の銀行」を
  出さない）、CFは期首残・営業・投資・財務・期末残の**5点すべて揃わなければ描かない**

## GraphQL API

エンドポイントは `POST /graphql` の1本、クエリも `financialReports` の1フィールドだけ
（開発環境のみ `/graphiql` にGraphiQLが立つ）。クエリ例とレスポンス構造（チャート契約）は
[11章](11_serving.md)が正。

未認証・公開エンドポイントである前提の防御:

| 防御 | 値・内容 |
|---|---|
| `limit` | 1〜100 |
| `stockCodes` | 最大100件 |
| クエリの複雑さ上限 | `max_complexity 400` / `max_depth 20` |
| limit連動のコスト計算 | `limit` の値が複雑度に加算される（`limit:1` と `limit:100` を同コスト扱いにしない） |

- 金額は独自スカラ `Money` で数値のまま返す（設計理由は[11章](11_serving.md)）
- `SearchQuery` は提出日降順。証券コードは4桁+`0`の5桁に変換して照合し、
  CFパターンは科目行の符号をEXISTSサブクエリで判定する
- スキーマは `rake graphql:dump_schema` で `schema.graphql` に書き出してコミットする運用

## テスト

| 種類 | 内容 |
|---|---|
| チャートBuilder | DB不要の純関数テスト。債務超過・貸借乖離・CF欠けなどを網羅 |
| Extractor | 実企業のXBRLをfixtureにした実データテスト。期待値は実測表から転記 |
| `mapping_consistency_spec` | 「全Extractorのマッピングキー ⊆ 科目コード定義」を機械検証 |
| 形式判定 | `format_detector_spec` で判定表・業種コードの大文字小文字ゆれ・unsupported落ちを検証 |
| fixture | 実XBRL8社分は1件数MBのためgit管理外。手元にないテストはskipされる（取得手順は `spec/fixtures/xbrl/README.md`） |

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
