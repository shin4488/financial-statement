# 移行・テスト・既知の限界

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

```ruby
# 期間を区切って実行。EDINET APIのレート制限のため同期・逐次（1日ずつ）
Ingestion::DailyIngestionService.run(from_date: Date.new(2016, 1, 1), to_date: Date.new(2016, 12, 31))
# ... 年ごとに繰り返し
```

- 全処理はupsert相当（find_or_initialize + 科目総入れ替え）のため再実行は冪等。訂正有報（docTypeCode 130）も同じ経路で上書きされる
- EDINET APIで遡れるのは**過去10年分**。それより古いデータが旧DBにある場合は、
  旧`security_reports`→新スキーマへの変換スクリプトを別途書く（旧カラム→科目コードの対応は
  [03](03_backend_ingestion.md)のJgaapGeneralマッピングの逆引きで機械的に決まる）。
  旧DBにはIFRS企業の連結が0埋めで入っているため、**IFRS行は変換対象から除外**し再取込に任せること
- 旧アプリと並行稼働させる場合、新テーブル群は名前が衝突しない（companies だけ衝突するため、
  並行期間中は新スキーマを別DB or `v2_` プレフィクスで作り、切替後にリネームするのが安全）

## 切替（今あるものを壊す手順）

1. 新スキーマ作成 → バックフィル完了まで旧アプリで運用
2. GraphQLエンドポイントを新スキーマ実装に切替（旧クエリ`companyFinancialStatements`は削除。
   フロントも同時リリース）
3. 安定後、旧テーブル（`security_reports`）・旧コード（`SecurityReport::*`）を削除

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
