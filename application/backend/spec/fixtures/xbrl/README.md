# 実XBRLフィクスチャ

Extractor系スペックの入力に使う実際の有報XBRL。**間引き済みでコミットされている**（1件数十〜数百KB）。

- 元の有報XBRLは1件数MBあるが、大半はテストが読まないHTML本文（TextBlock）のため、
  テストが読む範囲（標準4名前空間・当期/前期末/提出日コンテキスト・短いfact）だけに間引いてある。
  **数値は実際の開示値のまま**で、期待値の出典はリポジトリルートの docs/guide/07_taxonomy_mapping.md の実測表
- 間引きの条件と対象docIDの一覧は `lib/tasks/fixtures.rake` が正
- フィクスチャが無い場合、スペックはskipせず**失敗**する（コミット済みが前提のため）

## 取り直すとき（`EDINET_API_KEY` が必要）

新しい書類を足すときは `lib/tasks/fixtures.rake` の `DOC_IDS` と下の表に追記してから:

```bash
bundle exec rake fixtures:refresh_xbrl
```

Extractorが読むコンテキスト・名前空間を広げたときは、rake側の間引き条件（`KEEP_CONTEXTS` 等）も合わせて広げて取り直す。

| docID | 企業 | 検証ポイント |
|---|---|---|
| S100YB5L | 武田薬品 | ifrs_classified / 税引前損失 / その他損益が費用側 / のれん+無形の別掲合算 |
| S100YB25 | 三菱商事 | ifrs_classified / その他損益が収益側 / のれん無形の合算タグ / Revenue2IFRS |
| S100YCP3 | NTT | ifrs_classified / 収益が企業拡張タグ→経営指標サマリでフォールバック |
| S100XTNW | 楽天グループ | ifrs_liquidity判定 / 営業費用一括 / 当期赤字 |
| S100YLS8 | 東京海上HD | ifrs_liquidity / PL表示不可（収益が標準タグに存在しない） |
| S100YJQO | 三菱UFJ FG | jgaap_bank判定（業種DEI=bnk） / 経常収益型PL / 営業CF巨額マイナス |
| S100YQ6Y | イオン | jgaap_general / 営業収益型（OperatingRevenue1・OperatingCostのペア優先） |
| S100YR8L | インスペック | jgaap_general / 単体のみ / 売上原価=当期製品製造原価（CostOfProductsManufactured） |
| S100YDJC | 大成建設 | 建設（cns）: 標準タグの売上高・売上原価・販管費で描ける |
| S100YIHR | 東京電力HD | 電気（ele）: 営業費用一括型 / 有形・無形の標準タグがなく固定資産1段 / 単体は営業損失 |
| S100YC7N | JR東日本 | 鉄道（単体rwy）: 事業区分別の営業収益・営業費の合算 / 全事業営業利益（OperatingIncomeTotalBusiness） |
| S100YE63 | 東急 | 鉄道（連結・単体ともrwy）: 連結は営業費の内訳（運輸業等営業費及び売上原価+販管費）と一括の併記 → 内訳優先 / 単体は営業原価 |
| S100Y9T5 | 沖縄セルラー電話 | 電気通信（elc）: 電気通信事業+附帯事業の合算 / 固定資産1段 |
| S100Y90D | 玉井商船 | 海運（wat）: 海運業+その他事業の合算 / 一般管理費（GeneralAndAdministrativeExpensesWAT） |
| S100XTDX | 静岡ガス | ガス（gas）: 供給販売費及び一般管理費（…GAS）/ 単体はガス事業売上高（SalesFromGasBusinessGAS） |
| S100YANQ | いちよし証券 | 証券（sec）: 金融費用（pl.financial_expenses） |
| S100YI2V | アサックス | 特定金融（spf）: 営業費用一括に売上原価を併記 → 内訳では合わず一括で描く |
| S100YJB4 | 小林洋行 | 商品先物（cmd）: 売上原価 + 原価控除後の営業費用（OperatingExpensesCMD） / 単体は商品売上高より営業収益を優先 |
| S100Y0DB | Mマート | 投資業コード（inv）・単体のみ: 営業収益−汎用の営業費用（OperatingExpenses） |
| S100YD29 | かんぽ生命 | jgaap_insurance判定（連結・単体とも）/ 経常収益=OperatingIncomeINS / 保険契約準備金 |
| S100YCL0 | ソニーフィナンシャルG | 連結はjgaap_insurance / 単体は業種コードinsでも流動資産があるためjgaap_general |
| S100YE7T | 日本郵政 | 複数業種コード（bnk,ins）→ 先頭の銀行 / 貯金が企業拡張タグのためBSは描けない |
| S100SO41 | クリエイト・レストランツHD | ifrs_summary判定（2019年2月期=詳細タグ義務化前でjpigp_corが無い）/ 経営指標サマリからPL骨格+CF5点 |
