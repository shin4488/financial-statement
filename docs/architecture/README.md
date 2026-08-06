# アーキテクチャ

実際に動いているコードの構造と、そう作った理由をまとめたディレクトリ。

## 読む順序

上から順に読むと、設計の考え方 → データの形 → 処理の流れ、の順で頭に入る。

| # | 文書 | 内容 |
|---|---|---|
| 00 | [設計思想](00_layering.md) | **最初に読む。** 会計基準ごとの差異をどこに閉じ込めているか。層の分け方と、どこに何を書くべきかの判断基準 |
| 01 | [データモデル](01_data_model.md) | テーブル構成・縦持ちの実データ例・「行がない = 開示なし」の規約 |
| 02 | [取込層](02_ingestion.md) | EDINETからXBRLを取り込む流れ・形式判定・Extractor・失敗時のリカバリ |
| 03 | [表示層](03_serving.md) | ChartBuilder・チャート契約・GraphQL API |
| 04 | [フロントエンド](04_frontend.md) | 汎用チャートキット・Chrome拡張との共有方針・一覧ページ |

必要になったときに引く資料。

| # | 文書 | 使うとき |
|---|---|---|
| 05 | [タグ対応表](05_taxonomy_mapping.md) | XBRLタグを扱う作業のとき。タグ ↔ 科目コード ↔ Builder の一覧 |
| 06 | [XBRL実地調査](06_xbrl_research.md) | 新しい形式に対応するとき。6社・4形式の実測データ |
| 07 | [旧系統の削除手順](07_legacy_cleanup.md) | SecurityReport系を消すとき |

## 対応している形式

形式 = 「会計基準 × 表示様式」。会計基準だけでは決まらず、同じIFRSでもBSの様式が2種類ある。

| 形式 | 対象 | 実測に使った企業 |
|---|---|---|
| `jgaap_general` | 日本基準・一般事業会社 | 従来から表示できていた全企業 |
| `jgaap_bank` | 日本基準・銀行 | 三菱UFJ FG |
| `ifrs_classified` | IFRS・流動/非流動分類BS | 武田薬品・三菱商事・NTT |
| `ifrs_liquidity` | IFRS・流動性配列BS | 楽天グループ・東京海上HD |
| `unsupported` | US GAAP・日本基準の保険等 | チャートの代わりに説明文を出す（正常系） |

## 旧系統（SecurityReport系）との関係

2026-08-02に現行系統へ切り替え済み。2026-08-06に旧取込系（SubscriberService等）と旧画面を削除し、
旧クエリ系（`companyFinancialStatements`・`FetcherService`・`Company`/`SecurityReport`モデル）のみ
Chrome拡張向けに残置している。

| | 旧系統（停止・凍結） | 現行 |
|---|---|---|
| テーブル | `security_reports`（凍結・削除しない） | `companies`（共用）+ `reports` / `financial_statements` / `financial_statement_items` |
| GraphQL | `companyFinancialStatements`（残置） | `financialReports` |
| 画面 | 削除済み | `/` |
| 日次バッチ | ジョブごと削除済み | `DailyIngestionJob`（毎日2:00） |

Chrome拡張は `financialReports` へ移行済みのため、旧クエリを使うのはストア公開版の古い拡張だけになっている。削除の手順と順序は [07_legacy_cleanup.md](07_legacy_cleanup.md)。
