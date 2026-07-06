# 移行・テスト・既知の限界

## 作成ファイル全量チェックリスト

コード全文は各ドキュメントに記載済み（コードブロック先頭のパスコメントがファイルの置き場所）。
このリストを上から順に潰せば実装が完了する。

**バックエンド（application/backend）**

- [ ] Gemfile追記 + `bundle install`（[03](03_backend_ingestion.md) §0）
- [ ] `db/migrate/*_create_core_tables.rb`（[02](02_database.md)。共存戦略により先にRenameLegacyTables）
- [ ] `app/models/company.rb` / `report.rb` / `financial_statement.rb` / `financial_statement_item.rb`（02）
- [ ] `app/lib/financial_statements/item_codes.rb`（02）
- [ ] `app/lib/edinet/client.rb`（03）
- [ ] `app/lib/xbrl/document.rb`（03）
- [ ] `app/services/ingestion/dei_extractor.rb`（03）
- [ ] `app/services/ingestion/format_registry.rb` / `format_detector.rb`（03）
- [ ] `app/services/ingestion/extractors/base.rb` / `jgaap_general.rb` / `jgaap_bank.rb` / `ifrs_classified.rb` / `ifrs_liquidity.rb`（03）
- [ ] `app/services/ingestion/report_ingester.rb` / `daily_ingestion_service.rb`（03）
- [ ] `app/jobs/daily_ingestion_job.rb` + `config/sidekiq-cron.yml` 差し替え（03）
- [ ] `app/services/charts/structs.rb` / `builder_registry.rb`（[04](04_backend_api.md)）
- [ ] `app/services/charts/builders/stack_base.rb` + BS4種 + PL3種 + `cash_flow.rb`（04）
- [ ] `app/services/reports/search_query.rb`（04）
- [ ] `app/graphql/types/chart/` 5ファイル + `number_sign_type.rb` + `financial_report_type.rb` + `query_type.rb` 置換（04）
- [ ] `lib/tasks/ingestion.rake`（本ドキュメント）
- [ ] spec: factories（02）/ Extractorスペック（03）/ Builderスペック（04のマトリクス）

**フロントエンド（application/frontend）**

- [ ] `codegen.ts` 置き換え + `src/features/financialReports/{api,components}` 作成（[05](05_frontend.md) §0.5）
- [ ] `src/plugins/apollo/client.ts` / `src/App.tsx`（05 §0.5）
- [ ] `api/financialReports.query.ts` / `api/types.ts`（05 §9）→ `npm run compile`
- [ ] `components/colorRoles.ts` / `StackedBarChart.tsx` / `WaterfallChart.tsx` / `ChartUnavailable.tsx` / `ReportCard.tsx`（05 §4-8）
- [ ] `components/SearchForm.tsx` / `FinancialReportListPage.tsx`（05 §9）+ CSS追記
- [ ] 移行完了後にRedux関連を削除（05 §0.5）

## 実装順序

バックエンドの下層から積み上げる。各ステップが独立にテスト可能。

1. **基盤**: マイグレーション + モデル + `ItemCodes` + `FormatRegistry`（[02](02_database.md)）
2. **プリミティブ**: `Edinet::Client` / `Xbrl::Document`（Nokogiri導入）+ `DeiExtractor`
3. **Extractor**: `jgaap_general` → 実XBRLでスナップショットテスト → `ifrs_classified` → `ifrs_liquidity` → `jgaap_bank`
4. **Ingester**: `ReportIngester` + `DailyIngestionService` + job（sidekiq-cron設定は現行を流用）
5. **表示層**: `Charts::Builders`（純関数・単体テスト中心）→ GraphQL型 + `SearchQuery`
6. **フロント**: colorRoles / StackedBarChart / WaterfallChart → ReportCard → ListPage
7. **バックフィル** → 旧テーブル・旧コード削除

## 検証用docID（実測済み・期待値は[01](01_xbrl_format_research.md)の表）

| docID | 企業 | 検証ポイント |
|---|---|---|
| S100YB5L | 武田薬品 | ifrs_classified / 税引前損失 / その他損益が費用側 / のれん+無形の別掲合算 |
| S100YB25 | 三菱商事 | ifrs_classified / その他損益が収益側 / のれん無形の合算タグ / Revenue2IFRS |
| S100YCP3 | NTT | ifrs_classified / 収益が拡張タグ→サマリでフォールバック / 営業費用一括型 |
| S100XTNW | 楽天グループ | **ifrs_liquidity判定** / 営業費用一括 / 当期赤字 |
| S100YLS8 | 東京海上HD | ifrs_liquidity / **PL表示不可（収益が標準タグに存在しない）** / BS・CFは表示可 |
| S100YJQO | 三菱UFJ FG | **jgaap_bank判定（業種DEI=bnk）** / 経常収益型PL / 営業CF巨額マイナス |

追加で日本基準一般の任意の1社（現行アプリで表示できている企業）を回帰確認に使う。

### 動作確認手順（rails c）

```ruby
Dir.mktmpdir do |dir|
  ing = Ingestion::ReportIngester.new
  %w[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO].each { |id| ing.ingest(doc_id: id, work_dir: dir) }
end
FinancialStatement.where(is_primary: true).map { |fs|
  [fs.report.company.name_ja, fs.presentation_format, fs.items_hash["bs.assets"], fs.items_hash["pl.revenue"]]
}
# 東京海上のpl.revenueがnil（キーなし）、MUFGはpl.revenueなし・pl.ordinary_revenueあり、
# 各bs.assetsが01の表と一致すればOK
Charts::BuilderRegistry.build_all(FinancialStatement.where(is_primary: true).first)
```

## バックフィル（過去データ投入）

rakeタスクとして実装する（rails cの手打ちにしない理由: 長時間ジョブは中断・再開が前提になるため、
コマンド1つで任意期間を再実行できる形にしておく）:

```ruby
# lib/tasks/ingestion.rake
namespace :ingestion do
  desc "指定期間の有報をEDINETから取り込む 例: rake 'ingestion:backfill[2025-01-01,2025-12-31]'"
  task :backfill, [:from, :to] => :environment do |_, args|
    from = Date.parse(args.fetch(:from))
    to = Date.parse(args.fetch(:to))
    # DailyIngestionServiceは日単位でループし、日付・docIDをRails.loggerに出す。
    # 中断したらログの最終日付から再実行すればよい（全処理が冪等のため重複実行は無害）
    Ingestion::DailyIngestionService.run(from_date: from, to_date: to)
  end
end
```

実行（時間がかかるためnohup/tmux等で。有報ピークの6月は1日分で数百件×数MBのダウンロードになる）:

```bash
docker compose exec appserver bundle exec rake 'ingestion:backfill[2025-06-01,2025-06-30]'
```

- 全処理はupsert相当（find_or_initialize + 科目総入れ替え）のため再実行は冪等。訂正有報（docTypeCode 130）も同じ経路で上書きされる
- 進め方の推奨: **直近1年→動作確認→残り年を新しい順に**。ユーザー価値の高い直近データから埋まる
- EDINET APIで遡れるのは**過去10年分**。それより古いデータが旧DBにある場合は、
  旧`security_reports`→新スキーマへの変換スクリプトを別途書く（旧カラム→科目コードの対応は
  [03](03_backend_ingestion.md)のJgaapGeneralマッピングの逆引きで機械的に決まる）。
  旧DBにはIFRS企業の連結が0埋めで入っているため、**IFRS行は変換対象から除外**し再取込に任せること

## 切替（今あるものを壊す手順）

新旧のテーブルは `companies` だけ名前が衝突する。方式を先に決める:

| 方式 | 向いている状況 | 手順の要点 |
|---|---|---|
| A. 旧テーブルをリネームして共存（**推奨**） | 本番を止めずに移行したい | 下記詳細 |
| B. big-bang（旧を落として作り直し） | メンテ時間を取れる・データ消失を許容 | `db:migrate:reset` → 新マイグレーション → バックフィル。手順は単純だがバックフィル完了まで画面にデータがない |

### 方式Aの詳細手順

1. 旧テーブルのリネームマイグレーションを先に入れる:
   ```ruby
   class RenameLegacyTables < ActiveRecord::Migration[7.0]
     def change
       rename_table :companies, :legacy_companies
       rename_table :security_reports, :legacy_security_reports
     end
   end
   ```
   旧モデルにテーブル名を明示して**旧アプリはそのまま動かし続ける**:
   ```ruby
   class Company < ApplicationRecord
     self.table_name = "legacy_companies"  # 移行完了後にモデルごと削除する
   end
   class SecurityReport < ApplicationRecord
     self.table_name = "legacy_security_reports"
   end
   ```
2. 新スキーマのマイグレーション（[02](02_database.md)）を実行。旧アプリと新取込が同居する
3. 日次バッチを新ジョブ（`DailyIngestionJob`）に切替（[03](03_backend_ingestion.md) §0）。
   旧ジョブは止める（両方動かすとEDINETへのリクエストが倍になる）
4. バックフィル実行 → 動作確認（本ドキュメント冒頭の「検証用docID」6社 + 適当な日本基準企業）
5. GraphQLを新実装に切替（旧クエリ `companyFinancialStatements` を削除、新 `financialReports` を追加。
   フロントは新クエリを使う版を同時リリース。**新旧クエリを同時提供する移行期間は作らない**——
   利用者は自サイトのフロントのみで、後方互換を保つ相手がいないため）
6. 2週間ほど本番の日次取込・画面表示を監視して安定を確認
7. 後始末のマイグレーション: `drop_table :legacy_companies` / `drop_table :legacy_security_reports`、
   旧コード削除（下記リスト）、`schema.graphql` を再ダンプしてコミット

### 削除する旧コード一覧（方式A手順7 / 方式Bでは最初に削除）

```
app/models/company.rb（旧定義）・security_report.rb
app/services/security_report/subscriber_service.rb・fetcher_service.rb
app/repositories/security_report/reader_repository.rb・document_repository.rb
app/jobs/security_report_subscriber_job.rb
app/graphql/types/financial_statement/ 配下すべて（新チャート型に置換済みのため）
lib/app_file/xml_parser.rb（REXML依存。Xbrl::Documentに置換済み）
config/sidekiq-cron.yml の旧エントリ
フロント: src/pages/financialStatementList/・src/components/*BarChart/・Redux関連（05 §0.5参照）
```

## 既知の限界と対応方針

| 事象 | 挙動 | 将来の対応 |
|---|---|---|
| 保険IFRS（東京海上）の収益が企業拡張タグのみ | PLは表示不可（BS/CFは表示）。noteで明示 | 拡張タクソノミ（企業別xsd）を解決するか、`InsuranceRevenueIFRS`という要素ローカル名での横断検索を検討 |
| US GAAP（本表タグなし） | 全チャート表示不可 | `jpcrp_cor`経営指標サマリ（5年分）ベースの簡易表示を別形式として追加 |
| 日本基準の保険・証券・電力等の特定業種 | `unsupported`（表示不可） | 実XBRLを取得しタグ実測 → Extractor/Builder/判定表を追加（README記載の拡張手順） |
| 商社等の単体PLの科目ゆれ（三菱商事単体で売上高が取れない既知事象） | 単体PLの一部欠落（is_primaryは連結なので影響小） | pl.revenueのフォールバックに`OperatingRevenue`系を追加検討 |
| IFRSの単体開示（制度上ほぼ存在しない） | 単体はjgaap前提で取込（実測6社すべて該当） | 万一出現したらFormatDetectorが実タグで判定するよう1行変更 |

## 移行後に消えるもの（ゼロベース化の効果）

- `security_reports` の約60カラム横持ち（基準×連結単体×科目の直積カラム）
- `ReaderRepository` 内の基準・業種混在ロジックと `FetcherService` の巨大な整形メソッド
- フロントの科目別チャートコンポーネント（`balanceSheetBarChart` / `profitLossBarChart` /
  `cashFlowBarChart` / それぞれのchartData型）→ 汎用2コンポーネントに統合
- 「会計基準を増やす＝スキーマ変更＋全層改修」という構造。以後は形式追加=クラス追加のみ
