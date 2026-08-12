# 05. バックエンド

[04章](04_system_overview.md)の設計が実際にどう動くかを、取込 → 保存 → チャート生成 → API の
順で追う。実装の細部ではなく、業務上の事実と設計判断のレベルで説明する。
環境変数・起動・テスト実行などの手順は `application/backend/README.md` が正。

## コードの入口

| 役割 | 場所（application/backend/ 以下） |
|---|---|
| 日次バッチの入口（毎日2:00） | `app/jobs/daily_ingestion_job.rb`・`config/sidekiq-cron.yml` |
| 手動取込（日付範囲 / 書類ID指定） | `lib/tasks/ingestion.rake` |
| 取込パイプライン | `app/services/ingestion/`（Service・形式判定・Extractor） |
| EDINET通信・XBRLパース | `app/lib/edinet/client.rb`・`app/lib/xbrl/document.rb` |
| 科目コードの定義（取り決め1） | `app/lib/financial_statements/item_codes.rb` |
| 保存層のモデル | `app/models/disclosure/` |
| チャート組み立て・検索 | `app/services/charts/`・`app/services/disclosure/search_query.rb` |
| GraphQL | `app/graphql/` |

## 取込パイプライン

### 具体例: ある日のバッチで4件の書類が来たら

取込の設計（逐次実行・失敗の隔離・冪等・取り込まない判断）は、具体的な1日の動きで見るとわかりやすい。

| 書類 | 内容 | 何が起きるか |
|---|---|---|
| A | 通常の有報 | 保存される。1秒待って次へ |
| B | Aと同じ企業・同じ会計期間の訂正有報 | 新規追加ではなく**同じ行への上書き**になる（自然キーが「企業+会計期間」のため） |
| C | パース中に例外が発生 | ログ+Sentry通知して**次の書類へ進む**（Cだけが未取込になり、他は無事） |
| D | DEIの証券コードが一覧APIと不一致 | **保存せず**Sentryへ通知 |

翌日、通知に気づいたら `rake 'ingestion:documents[Cの書類ID]'` で再取込する。
全処理が冪等なので、A・Bごと再実行しても壊れない（リカバリ手順は[07章](07_development_operations.md)）。

### 信頼性を支える設計判断

| 設計 | 理由（業務上の背景） |
|---|---|
| 同期・逐次 + 書類間1秒待ち。**並列化しない** | EDINET APIはリクエスト過多で403を返して遮断する |
| DEI（提出者が書くメタ情報）を信用せず、EDINETコードの形式と一覧APIの証券コードで検証してから使う | なりすましも提出ミスも同じ経路で起き、検証なしだと**他社レコードを上書き**し得る |
| 自動リトライなし・冪等な再実行だけ | リトライの複雑さを持ち込むより、いつ何度実行しても安全な方が運用が単純になる |
| 企業拡張タグ（企業が独自定義したタグ）はパース段階で捨てる | 企業ごとに意味の保証がなく、誤った値を拾うリスクの方が大きい |
| 数値として不正な値は「0円」でなく「取得できず」として扱う | 「開示なし」と「0円」の区別（[04章](04_system_overview.md)の規約）が壊れるため |

### 保存時の防御

| 防御 | 目的 |
|---|---|
| 企業マスタの社名更新は最新年度の取込時のみ | 過去年度のバックフィルで社名が古いものに巻き戻らない |
| 科目が空で既存データがあるならスキップ | 財務データを含まない訂正有報が、正しいデータを空で潰さない |
| 科目は削除→一括挿入で総入れ替え | 訂正で消えた科目は消える必要がある（「行がない=開示なし」を保つ） |
| 連結がなくなった有報では旧連結行を削除 | 連結廃止時に古い表示用データが残らない |

既知のエッジケース（fail-safe方向・対応不要）: 「連結廃止をDEIで伝え、かつ財務データを
含まない訂正有報」が来ると、その有報が一覧から一時的に消える（Sentry警告あり。
次の正常な取込で復元される）。

### XBRLからの値の取り出し

データは次の3段階で変換される。

```
① XBRLの中の1つのfact（XML）
   <jppfs_cor:Assets contextRef="CurrentYearInstant" ...>100000000</jppfs_cor:Assets>

② パース後の辞書（タグ+コンテキスト → 値）
   { ["jppfs_cor", "Assets", "CurrentYearInstant"] => "100000000" }

③ Extractorによる取り出し → 科目コードへ
   money("jppfs_cor:Assets", "CurrentYearInstant")  #=> 100000000 を bs.assets として保存
```

Extractorは実質「タグ → 科目コードの対応表」で、ロジックをほぼ持たない。
1科目に複数タグを並べると先頭から順に探すフォールバックになり、
**企業・業種ごとの科目名のゆれをここで吸収する**。

```ruby
# 売上のフォールバック（jgaap_general。順序が優先度）
"pl.revenue" => %w[
  jppfs_cor:OperatingRevenue1    # 営業収益
  jppfs_cor:NetSales             # 売上高（最も一般的）
  jppfs_cor:ContractsCompletedRevOA                      # 完成工事高
  jppfs_cor:NetSalesOfCompletedConstructionContractsCNS  # 完成工事高（建設業）
]
# 建設業の有報にはNetSalesのfactがない → 3〜4番目で初めて値が取れる
```

| Extractor | 特徴 |
|---|---|
| `JgaapGeneral` | 売上4段・売上原価8段のフォールバック |
| `JgaapBank` | 貸出金・預金など銀行専用タグ。**経常収益（`OrdinaryIncomeBNK`）と経常利益（`OrdinaryIncome`）は似た名前で桁が兆単位で違う** |
| `IfrsClassified` | 非流動負債はタクソノミ公式のタイポ（`NonCurrentLabilitiesIFRS`）を先に引く |
| `IfrsLiquidity` | BSは合計系のみ。PL/CFは`IfrsClassified`と定数を共有（継承はしない。[04章](04_system_overview.md)） |

同じ入口から、形式によって違う科目が出てくる（キーが無い = 開示なし）。

| 科目コード | 武田薬品（ifrs_classified） | 三菱UFJ FG（jgaap_bank） |
|---|---|---|
| bs.assets | 15.5兆 | 431.7兆 |
| bs.current_assets | 3.09兆 | キーなし（銀行に流動区分がない） |
| bs.loans / bs.deposits | キーなし | 133.8兆 / 239.4兆 |
| pl.revenue | 4.5兆 | キーなし（銀行に売上高がない） |
| pl.ordinary_revenue | キーなし | 14.6兆 |

全科目のタグ対応と6社の実測データは[08章](08_taxonomy_mapping.md)
（**XBRLタグを触る作業の前に必読**）。

### 新形式の追加手順（例: 日本基準・保険業）

1. 対象企業の有報XBRLを1件取得してタグを実測する
2. Extractorクラスを追加（マッピング定数が本体）
3. 判定表・登録表に1行ずつ追加
4. 必要なら科目コードを追加
5. 表示側のBuilderを追加（次節）
6. 実測値でスペックを書き、[08章](08_taxonomy_mapping.md)の表を更新する

**DBマイグレーション・GraphQL・フロントの変更はなし**（[04章](04_system_overview.md)の層設計の狙いどおり）。

## チャート生成

### チャート構造（取り決め2の中身）

バックエンドが「チャートの構造そのもの」まで組み立てて返す。フロント・Chrome拡張と共有する構造は次の2種類。

```
StackChart（BS/PL用）                     WaterfallChart（CF用）
├ renderable: 描けるか                    ├ renderable
├ note: 描けない理由の説明文               ├ note
└ bars: [                                └ steps: [
    { label: "借方",                         { key, label: "期首残",
      segments: [                              amount: 符号付き円,
        { key, label,                          kind: "balance" },   # 0起点で描く
          amount: 描画高さ(常に≥0),           { key, label: "営業CF",
          signedAmount: 実値(負もある),         amount: -23兆もあり得る,
          ratio: 34.8,                         kind: "flow" },      # 累積から浮かせる
          colorRole: "expense1" }, ... ] } ]   ... ]
```

| 構造の仕掛け | 吸収する業務上の差異 |
|---|---|
| `segments[]` をそのまま積む（固定キーなし） | 形式ごとの段数・科目の違い（銀行BS 4段 / IFRS流動性配列 2段…） |
| `colorRole`（意味ベースの色の役割名） | 「何色にするか」。新科目にも既存の役割を割り当てるだけ |
| `amount`（高さ）と `signedAmount`（実値）の分離 | 赤字・債務超過（負値を棒グラフに渡すと逆向きに描かれる） |
| `spacer` セグメント | 債務超過時の3本目バーの位置合わせ（透明の詰め物） |
| `renderable: false` + `note` | 「この表は出せない」を**正常系のデータ**として返す |
| `kind: balance / flow` | CFの残高（0起点）と増減（浮かせる）の描き分け + 為替換算差額の吸収 |

### 実例1: 武田薬品のPL（赤字 + 残差の導出）

[04章](04_system_overview.md)で保存した行が、チャートになるまで。入力（単位: 百万円）:

| 科目コード | 金額 |
|---|---|
| pl.revenue | 4,505,720 |
| pl.cost_of_sales | 1,571,588 |
| pl.sga | 1,084,215 |
| pl.profit_before_tax | -142,355 |

開示されている費用だけでは貸借が合わないため、差額を「その他損益（純額）」として導出する。

```
その他損益（純額） = 税引前利益 - (収益 - 開示済み費用) = -1,992,272 → 負なので費用側へ
```

| バー | セグメント | ratio |
|---|---|---|
| 借方 | 売上原価 / 販管費 / その他損益（純額） | 34.8% / 24.0% / -44.2% |
| 貸方 | 収益 / 税引前損失 | 100% / -3.1% |

残差項目のおかげで借方合計と貸方合計は常に一致し、赤字（税引前損失）は貸方に積んで
高さを揃える。銀行BSも同じ考え方で、内訳科目が多すぎて全部は描けないため、主要科目
（現金預け金・貸出金・有価証券・預金）だけタグで取り、「その他資産」「その他負債」を合計との残差で導出する。

### 実例2: 表示不可も正常系（東京海上のPL）

保険IFRSは収益が企業拡張タグのみで標準タグから取れない（実測は[08章](08_taxonomy_mapping.md)）。
その場合も**カード全体を落とさず、取れなかったチャートだけ**説明文にする。

```json
{ "profitLoss":   { "renderable": false,
                    "note": "損益計算書: この企業のIFRS損益計算書は表示に対応していません。" },
  "balanceSheet": { "renderable": true, "bars": [...] },
  "cashFlow":     { "renderable": true, "steps": [...] } }
```

### Builderの分担と共通ルール

| 形式 | BS | PL | CF |
|---|---|---|---|
| `jgaap_general` | 流動/固定の4段 | 原価・販管費・営業利益 | 全形式共通（期首残→営業→投資→財務→期末残） |
| `jgaap_bank` | 主要科目+残差 | 経常収益/費用/利益 | 同上 |
| `ifrs_classified` | 流動/非流動 | 費用+税引前利益（残差つき） | 同上 |
| `ifrs_liquidity` | 現金+残差 | ifrs_classifiedと共通 | 同上 |
| `unsupported` | 「表示に対応していません」（renderable: false） | 同左 | 同上 |

形式によらない共通ルールは基底クラスに1回だけ書く（形式別Builderには書かせない）。

- **借方合計と貸方合計の乖離が1割を超えたら描かない**（誤ったグラフより出さない方を選ぶ）
- 必須科目が欠けたら描かない。銀行BSは預金がなければ描かず（「預金0%の銀行」を出さない）、
  CFは5点すべて揃わなければ描かない
- 債務超過は3本目のバー「債務超過」を作り、透明な`spacer`で高さを合わせて描く
- 比率はBigDecimalで計算して小数1桁に切り捨て（「19.900000000000002%」や合計100%超を防ぐ）

## GraphQL API

エンドポイントは `POST /graphql` の1本、クエリも `financialReports` の1フィールドだけ。

```graphql
query {
  financialReports(limit: 30, offset: 0,
                   stockCodes: ["4502"],          # 4桁。5桁化はバックエンドの責務
                   operatingCfSign: POSITIVE) {   # CFパターン絞り込み
    companyName
    accountingStandard      # バッジ表示のみに使う。描画分岐に使わない（規律）
    balanceSheet { renderable note bars { label segments { key label amount signedAmount ratio colorRole } } }
    profitLoss   { ... }
    cashFlow     { renderable note steps { key label amount kind } }
  }
}
```

**未認証・公開エンドポイント**である前提の防御と設計:

| 設計 | 内容・理由 |
|---|---|
| 入力量の上限 | `limit` 1〜100、`stockCodes` 最大100件、クエリ複雑度400・深さ20まで |
| `limit` 連動のコスト計算 | ライブラリ既定は引数を見ず `limit:1` と `limit:100` が同コストになるため、`limit` を複雑度に加算する |
| 金額は独自スカラ `Money`（JSON数値のまま返す） | 標準のBigInt型は文字列になり、Web・Chrome拡張の両方に変換処理が必要になる。日本企業の最大級の総資産400兆円=4×10^14はJavaScriptの安全整数9×10^15に収まる |
| 検索は提出日降順・CFパターンは科目行の符号で判定 | 絞り込み対象は `is_primary`（連結優先）の財務諸表だけ |

フィールドを増やすときは複雑度の実測値（一覧54 / Chrome拡張89 / 型生成のイントロスペクション187。
上限400）に収まるか確認する。スキーマは `rake graphql:dump_schema` で
`schema.graphql` に書き出してコミットする運用（手順は[07章](07_development_operations.md)）。

## テスト

| 種類 | 内容 |
|---|---|
| チャートBuilder | DB不要の純関数テスト。債務超過・貸借乖離・CF欠けなどを網羅 |
| Extractor | 実企業のXBRLをfixtureにした実データテスト。期待値は[08章](08_taxonomy_mapping.md)の実測表から転記 |
| マッピング整合 | 「全Extractorのマッピングキー ⊆ 科目コード定義」を機械検証 |
| 形式判定 | 判定表・業種コードの大文字小文字ゆれ・unsupported落ちを検証 |
| fixture | 実XBRL8社分は1件数MBのためgit管理外。手元にないテストはskipされる（取得手順は `spec/fixtures/xbrl/README.md`） |
| CI | push/PRごとにrubocop・スキーマ差分検知・rspecを実行（`.github/workflows/ci.yml`） |

---

次章: [06. フロントエンド実装](06_frontend.md)
