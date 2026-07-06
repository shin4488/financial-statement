# IFRS財務情報 取得・表示対応 実装方針

> **注**: 本ディレクトリは既存テーブル・実装を前提とした段階改修案。
> ゼロベースで再設計する場合の方針は [docs/zero-base-redesign/](../zero-base-redesign/README.md) を参照（そちらが最新の推奨案）。

## 目的

現在は日本基準（japan_gaap）の有価証券報告書のみ財務3表（BS/PL/CF）の取得・表示に対応している。
IFRS採用企業（accounting_standard = ifrs）の連結財務3表も取得・表示できるようにする。

## 背景（現状の問題）

IFRS採用企業の連結財務諸表は、XBRL上で日本基準用タクソノミ `jppfs_cor` ではなく
**IFRS用タクソノミ `jpigp_cor`** でタグ付けされている。
現行の `SecurityReport::ReaderRepository` は `jppfs_cor` の要素のみを参照しているため、
IFRS企業では連結財務諸表の全カラムが 0 で保存される（`reader_repository.rb` の TODO コメントに記載の既知事象）。

実際に武田薬品工業（S100YB5L）・三菱商事（S100YB25）の有報XBRLを取得して
`SecurityReport::ReaderRepository#read` を実行し、連結が全て 0、単体（日本基準のまま）は取得できることを確認済み。
詳細は [01_xbrl_research.md](01_xbrl_research.md) を参照。

## 決定事項（ユーザー確認済み）

| 論点 | 決定 |
|---|---|
| グラフ表示 | 日本基準グラフへの近似マッピングではなく、**IFRS本来の構造に合わせた専用グラフ構成**にする |
| テーブル設計 | 既存 `security_reports` へのカラム追加ではなく、**IFRS用の別テーブルを新設**する（疎結合） |

## スコープ

- 対象: **IFRSの連結財務諸表**（BS/PL/CF）
- 対象外:
  - US GAAP（`us_gaap`）。EDINETタクソノミではUS GAAPの本表は詳細タグ付けされないため対応不可
  - IFRS企業の単体財務諸表 … 日本の制度上、単体は日本基準で作成されるため**既存ロジックのままで取得できている**（変更不要）
  - 日本基準の未対応業種（金融機関等の特定業種フォーマット）… 既存の別課題
  - 三菱商事の単体PLで売上高が0になる問題（商社単体のPL科目差異）… 既存の別課題

## 設計の全体像

```
EDINET API ──> SubscriberService ──> ReaderRepository（ヘッダ/DEI読取り + 会計基準判定）
                                        ├─ JapanGaapStatementReader（既存ロジックを移設: jppfs_cor）
                                        └─ IfrsStatementReader（新規: jpigp_cor）
                                     ──> DB
                                          ├─ security_reports（共通ヘッダ + 日本基準の科目: 既存のまま）
                                          └─ ifrs_financial_statements（新設: IFRS連結の科目）
GraphQL FetcherService ──> accounting_standard で Presenter を切替
                              ├─ JapanGaapPresenter（既存の整形ロジックを移設）
                              └─ IfrsPresenter（新規）
React ──> accountingStandard で描画コンポーネントを切替
             ├─ BalanceSheetBarChart / ProfitLossBarChart（既存: 日本基準用）
             └─ IfrsBalanceSheetBarChart / IfrsProfitLossBarChart（新規）
             └─ CashFlowBarChart（CF は構造が共通のため既存を共用）
```

高凝集・疎結合の方針:

- 会計基準ごとの知識（XBRLタグ、科目構成、比率計算、グラフ構成）を **基準別のクラス/コンポーネントに閉じ込める**
- 既存の日本基準の処理・テーブル・グラフは**変更せず**（リファクタによる移設のみ）、IFRSを追加しても互いに影響しない構造にする
- 会計基準の判定・振り分けは Reader / Presenter / フロントの各層で1箇所ずつに限定する

## ドキュメント構成

| ファイル | 内容 |
|---|---|
| [01_xbrl_research.md](01_xbrl_research.md) | IFRS企業のXBRL実地調査結果（武田薬品・三菱商事）。タグ一覧・注意点 |
| [02_database_design.md](02_database_design.md) | `ifrs_financial_statements` テーブル設計・マイグレーション方針 |
| [03_backend_design.md](03_backend_design.md) | Reader分割、Subscriber・FetcherService・GraphQLの変更設計 |
| [04_frontend_design.md](04_frontend_design.md) | GraphQLクエリ、IFRS専用グラフコンポーネント設計 |
| [05_implementation_steps.md](05_implementation_steps.md) | 実装手順、テスト観点、過去データのバックフィル手順 |
