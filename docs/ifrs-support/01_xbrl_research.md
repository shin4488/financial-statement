# IFRS XBRL 実地調査結果

## 調査方法

代表的なIFRS採用企業として業種の異なる2社を選定し、EDINET API v2（アプリと同じエンドポイント・APIキー）で
有価証券報告書のXBRL（`*/PublicDoc/*.xbrl`）を取得して全factをダンプ・分析した。
さらに既存の `SecurityReport::ReaderRepository#read` を同ファイルに対して実行し、現行ロジックの挙動を確認した。

| 企業 | 業種 | 証券コード | docID | 対象期 |
|---|---|---|---|---|
| 武田薬品工業 | 医薬品（メーカー型PL: 営業利益あり） | 4502 | S100YB5L | 2025/04/01–2026/03/31（2026-06-17提出） |
| 三菱商事 | 卸売業・総合商社（商社型PL: 売上総利益あり・営業利益なし） | 8058 | S100YB25 | 2025/04/01–2026/03/31（2026-06-12提出） |

## 確認結果サマリ

1. **名前空間**: IFRS連結財務諸表の科目は `jpigp_cor`（EDINETのIFRS用タクソノミ）でタグ付けされる。
   `jppfs_cor`（日本基準用）の連結コンテキスト（`CurrentYearInstant` / `CurrentYearDuration`）のfactは **1件も存在しない**。
   → 現行Readerでは連結が全て0になる（両社で実証済み）。
2. **コンテキストIDは日本基準と共通**:
   - 連結: `CurrentYearInstant` / `CurrentYearDuration` / `Prior1YearInstant`（サフィックスなし）
   - 単体: `..._NonConsolidatedMember`
3. **単体財務諸表は日本基準のまま** `jppfs_cor` + `_NonConsolidatedMember` でタグ付けされる
   （武田216 fact、三菱商事238 factを確認）。単体の取得ロジックは変更不要。
4. **DEI要素（`jpdei_cor`）は既存どおり取得可能**: `AccountingStandardsDEI` = `IFRS`、
   `WhetherConsolidatedFinancialStatementsArePreparedDEI` = `true` 等。
5. **PLの構成は企業によって異なる**（下表）。BS/CFはほぼ共通。

## BS（連結財政状態計算書）: 観測タグ

コンテキストはすべて `CurrentYearInstant`。単位は円。

| 概念 | XBRL要素（jpigp_cor:） | 武田 | 三菱商事 |
|---|---|---|---|
| 流動資産合計 | `CurrentAssetsIFRS` | ✔ | ✔ |
| 非流動資産合計 | `NonCurrentAssetsIFRS` | ✔ | ✔ |
| 資産合計 | `AssetsIFRS` | ✔ | ✔ |
| 有形固定資産 | `PropertyPlantAndEquipmentIFRS` | ✔ | ✔ |
| のれん | `GoodwillIFRS` | ✔ | −（下と合算） |
| 無形資産 | `IntangibleAssetsIFRS` | ✔ | − |
| のれん及び無形資産 | `GoodwillAndIntangibleAssetsIFRS` | − | ✔ |
| 現金及び現金同等物 | `CashAndCashEquivalentsIFRS` | ✔ | ✔ |
| 流動負債合計 | `TotalCurrentLiabilitiesIFRS` ※注1 | ✔ | ✔ |
| 非流動負債合計 | `NonCurrentLabilitiesIFRS` ※注2 | ✔ | ✔ |
| 負債合計 | `LiabilitiesIFRS` | ✔ | ✔ |
| 親会社所有者帰属持分 | `EquityAttributableToOwnersOfParentIFRS` | ✔ | ✔ |
| 非支配持分 | `NonControllingInterestsIFRS` | ✔ | ✔ |
| 資本合計 | `EquityIFRS` | ✔ | ✔ |
| 負債及び資本合計 | `LiabilitiesAndEquityIFRS` | ✔ | ✔ |

- ※注1: 日本基準の `CurrentLiabilities` と異なり **`Total` プレフィクス付き**。念のため `CurrentLiabilitiesIFRS` もフォールバックに入れること。
- ※注2: タクソノミ側のスペルが **`NonCurrentLabilities`（Liabilitiesのタイポ）** である。観測された実タグ。
  `NonCurrentLiabilitiesIFRS`（正しい綴り）もフォールバックに入れること。
- 日本基準にある「有形固定資産/無形固定資産/投資その他の資産」の3分類は存在しない。資産は流動/非流動の2分類。
- 流動資産・非流動資産の内訳科目（棚卸資産、営業債権等）は企業ごとに構成が異なる（例: 三菱商事のみ `BiologicalAssetsCAIFRS` 等）。

## PL（連結損益計算書）: 観測タグ

コンテキストはすべて `CurrentYearDuration`。

| 概念 | XBRL要素（jpigp_cor:） | 武田 | 三菱商事 |
|---|---|---|---|
| 収益（売上収益） | `RevenueIFRS` / `Revenue2IFRS` ※注3 | ✔ (`RevenueIFRS`) | ✔ (`Revenue2IFRS`) |
| 売上原価 | `CostOfSalesIFRS` | ✔ | ✔ |
| 売上総利益 | `GrossProfitIFRS` | **なし** | ✔ |
| 販売費及び一般管理費 | `SellingGeneralAndAdministrativeExpensesIFRS` | ✔ | ✔ |
| 営業利益 | `OperatingProfitLossIFRS` | ✔ | **なし** |
| 金融収益 | `FinanceIncomeIFRS` | ✔ | ✔ |
| 金融費用 | `FinanceCostsIFRS` | ✔ | ✔ |
| 持分法投資損益 | `ShareOfProfitLossOfInvestmentsAccountedForUsingEquityMethodIFRS` | ✔ | ✔ |
| 税引前利益 | `ProfitLossBeforeTaxIFRS` | ✔ | ✔ |
| 法人所得税費用 | `IncomeTaxExpenseIFRS` | ✔ | ✔ |
| 当期利益 | `ProfitLossIFRS` | ✔ | ✔ |
| 親会社所有者帰属当期利益 | `ProfitLossAttributableToOwnersOfParentIFRS` | ✔ | ✔ |

- ※注3: 収益のタグは企業により異なる。`RevenueIFRS` / `Revenue2IFRS` の他、タクソノミ上は
  `NetSalesIFRS`・`OperatingRevenuesIFRS`・`SalesIFRS` 等の系列があるため、フォールバックリスト方式で読む。
  **確実なフォールバック**として `jpcrp_cor:RevenueIFRSSummaryOfBusinessResults`（経営指標サマリの売上収益、
  contextRef=`CurrentYearDuration`）が両社に存在し、本表の値と一致することを確認済み。
- **経常利益・営業外収益/費用・特別利益/損失はIFRSに概念が存在しない。**
- 売上総利益・営業利益は**開示自体が任意**のため企業により有無が異なる（上表のとおり）→ DBはNULL許容にし、グラフ側は導出項目で吸収する（04参照）。

## CF（連結キャッシュ・フロー計算書）: 観測タグ

| 概念 | XBRL要素（jpigp_cor:） | contextRef | 武田 | 三菱商事 |
|---|---|---|---|---|
| 営業活動によるCF | `NetCashProvidedByUsedInOperatingActivitiesIFRS` | CurrentYearDuration | ✔ | ✔ |
| 投資活動によるCF | `NetCashProvidedByUsedInInvestingActivitiesIFRS` ※注4 | CurrentYearDuration | ✔ | ✔ |
| 財務活動によるCF | `NetCashProvidedByUsedInFinancingActivitiesIFRS` | CurrentYearDuration | ✔ | ✔ |
| 期首残高 | `CashAndCashEquivalentsIFRS` | **Prior1YearInstant** | ✔ | ✔ |
| 期末残高 | `CashAndCashEquivalentsIFRS` | CurrentYearInstant | ✔ | ✔ |

- ※注4: 日本基準の `NetCashProvidedByUsedInInvestmentActivities`（Investment）と異なり **Investing**。
- 期首=前期末（Prior1YearInstant）とする考え方は既存の日本基準ロジックと同じでよい。

## 現行Readerの実行結果（実証）

`bundle exec rails runner` で `SecurityReport::ReaderRepository#read` を両社のXBRLに対して実行した結果:

- `accounting_standard: "ifrs"` は正しく判定される（既存実装のまま利用可）
- `consolidated_statement`: **全項目 0**（jppfs_corに連結factがないため）
- `non_consolidated_statement`: 日本基準どおり取得できる（BS/PLに値あり。単体CFは元々開示がないため0）

## その他の分析情報

- `jpcrp_cor` の経営指標サマリ（`...IFRSSummaryOfBusinessResults` 系列）には
  売上収益・税引前利益・当期利益・親会社帰属利益・営業/投資/財務CF・現金同等物残高の
  当期+過去4期分が入っている。本表タグが取れない場合の最終フォールバックとして利用可能。
- 調査に使用したスクリプトはリポジトリに含めていない（scratchpad上で実行）。
  再現する場合は EDINET API `documents.json`（type=2）で docID を特定し、
  `documents/{docID}?type=1` でzipを取得して `*/PublicDoc/*.xbrl` を展開すればよい
  （`SubscriberService::IndividualSubscriber` と同じ手順）。
