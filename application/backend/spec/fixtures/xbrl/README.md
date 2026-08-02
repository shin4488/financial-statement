# 実XBRLフィクスチャ

Extractor系スペックの入力に使う実際の有報XBRL。1件数MBあるためgit管理せず、
必要なときに以下でEDINETから取得する（`EDINET_API_KEY` が必要）:

```bash
bundle exec rails runner '
  client = Edinet::Client.new
  dir = Rails.root.join("spec/fixtures/xbrl").to_s
  %w[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO S100YQ6Y S100YR8L].each do |doc_id|
    path = client.download_xbrl(doc_id: doc_id, work_dir: dir)
    puts "#{doc_id}: #{path}"
  end
'
```

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

期待値の出典は docs/architecture/06_xbrl_format_research.md の実測表。
フィクスチャが存在しない場合、該当スペックはskipされる。
