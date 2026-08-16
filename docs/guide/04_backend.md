# 04. バックエンド

[03章](03_system_overview.md)の設計が実際にどう動くかを、取込 → 保存 → チャート生成 → API の順で追う。実装の細部ではなく、業務上の事実と設計判断のレベルで説明する。環境変数・起動・テスト実行などの手順は `application/backend/README.md` が正。

## 使っている技術

| 技術 | 役割 |
|---|---|
| Ruby on Rails | Webアプリケーションフレームワーク。画面を返さないAPIモードで使用 |
| ActiveRecord | RailsのORM。DBのテーブルをRubyのクラスとして扱う。スキーマ変更は「マイグレーション」ファイルで管理する |
| graphql-ruby | GraphQLサーバ実装。スキーマ・型・リゾルバをRubyで定義する |
| puma | Railsを動かすアプリケーションサーバ |
| Sidekiq | 非同期ジョブ実行基盤。ジョブの受け渡しにRedisを使う |
| sidekiq-cron | Sidekiqに「毎日2:00に実行」のようなスケジュール実行を加える拡張 |
| Nokogiri | XMLパーサ。XBRLの解析に使う |
| figaro | 環境変数を `config/application.yml`（gitignore済み）で管理するgem |
| Sentry | エラー監視サービス。例外や警告を集約し通知する |

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

取込の設計（逐次実行・失敗の隔離・冪等・取り込まない判断）を、ある1日の動きで追う。

| 書類 | 内容 | 何が起きるか |
|---|---|---|
| A | 通常の有報 | 保存される。1秒待って次へ |
| B | Aと同じ企業・同じ会計期間の訂正有報 | 新規追加ではなく**同じ行への上書き**になる（自然キーが「企業+会計期間」のため） |
| C | パース中に例外が発生 | ログ+Sentry通知して**次の書類へ進む**（Cだけが未取込になり、他は無事） |
| D | DEIの証券コードが一覧APIと不一致 | **保存せず**Sentryへ通知 |

翌日、通知に気づいたら `rake 'ingestion:documents[Cの書類ID]'` で再取込する。全処理が冪等なので、A・Bごと再実行しても壊れない（リカバリ手順は[06章](06_development_operations.md)）。

### 信頼性を支える設計判断

| 設計 | 理由（業務上の背景） |
|---|---|
| 同期・逐次 + 書類間1秒待ち。**並列化しない** | EDINET APIはリクエスト過多で403を返して遮断する |
| DEI（提出者が書くメタ情報）を信用せず、EDINETコードの形式と一覧APIの証券コードで検証してから使う | なりすましも提出ミスも同じ経路で起き、検証なしだと**他社レコードを上書き**し得る |
| 自動リトライなし・冪等な再実行だけ | リトライの複雑さを持ち込むより、いつ何度実行しても安全な方が運用が単純になる |
| 企業拡張タグ（企業が独自定義したタグ）はパース段階で捨てる | 企業ごとに意味の保証がなく、誤った値を拾うリスクの方が大きい |
| 数値として不正な値は「0円」でなく「取得できず」として扱う | 「開示なし」と「0円」の区別（[03章](03_system_overview.md)の規約）が壊れるため |

### 保存時の防御

| 防御 | 目的 |
|---|---|
| 企業マスタの社名更新は最新年度の取込時のみ | 過去年度のバックフィルで社名が古いものに巻き戻らない |
| 科目が空で既存データがあるならスキップ | 財務データを含まない訂正有報が、正しいデータを空で潰さない |
| 科目は削除→一括挿入で総入れ替え | 訂正で消えた科目は消える必要がある（「行がない=開示なし」を保つ） |
| 連結がなくなった有報では旧連結行を削除 | 連結廃止時に古い表示用データが残らない |

既知のエッジケース（安全側に倒れるため対応不要）: 「連結廃止をDEIで伝え、かつ財務データを含まない訂正有報」が来ると、その有報が一覧から一時的に消える（Sentry警告あり。次の正常な取込で復元される）。

### XBRLからの値の取り出し

fact → 辞書 → 科目コードと変換される全体像は、[07章](07_taxonomy_mapping.md)冒頭のデータフロー図のとおり。Extractorは実質「タグ → 科目コードの対応表」で、ロジックをほぼ持たない。対応表の値は3記法で、**企業・業種ごとの科目名のゆれをここで吸収する**。

| 記法 | 意味 | 例 |
|---|---|---|
| `"jppfs_cor:NetSales"` | 単一タグ | 資産合計など |
| `[ "…:A", "…:B", … ]` | フォールバック（先頭から順に探し、最初に取れた値を採用） | 売上高（営業収益・完成工事高などのゆれ） |
| `sum("…:A", "…:B")` | 合算（存在するタグだけを足す。1つも無ければ「開示なし」） | 合計タグを持たず事業区分別に開示する鉄道単体・電気通信・海運の営業収益 |

```ruby
# 売上のフォールバック（jgaap_general。順序が優先度。JgaapGeneral::DURATION_MAPPING から抜粋）
"pl.revenue" => [
  "jppfs_cor:OperatingRevenue1",     # 営業収益
  "jppfs_cor:OperatingRevenueELE",   # 営業収益（電気）… 業種固有の合計タグ
  "jppfs_cor:NetSales",              # 売上高（最も一般的）
  "jppfs_cor:NetSalesOfCompletedConstructionContractsCNS",  # 完成工事高（建設業）
  # 鉄道（単体）: 営業収益の合計タグがなく事業区分別にしか開示しないため、区分タグを合算する
  # （存在するタグだけを足す。鉄道事業だけの会社も、鉄道+不動産+開発の会社も同じ1行で引ける）
  sum("jppfs_cor:OperatingRevenueRailwayRWY",      # 鉄道事業営業収益
      "jppfs_cor:OperatingRevenueRailroadRWY",     # 鉄軌道事業営業収益
      "jppfs_cor:OperatingRevenueRelatedRWY",      # 関連事業営業収益
      "jppfs_cor:OperatingRevenueIncidentalRWY",   # 付帯事業営業収益
      "jppfs_cor:OperatingRevenueSideLineRWY",     # 兼業営業収益
      "jppfs_cor:OperatingRevenueRealEstateRWY",   # 不動産事業営業収益
      "jppfs_cor:OperatingRevenueDevelopmentRWY",  # 開発事業営業収益
      "jppfs_cor:OperatingRevenueAutomobileRWY",   # 自動車事業営業収益
      "jppfs_cor:OperatingRevenueOtherRWY")        # その他事業営業収益
]
```

例えばJR東日本の単体は鉄道事業 2,020,442百万円と関連事業 205,293百万円しか開示していないので、この合算は 2,225,735百万円（=`pl.revenue`）になる。

業種固有のタグ（`…ELE` `…RWY` のように業種の接尾辞が付く）はその業種の有報にしか現れないため、リストの中で業種をまたぐ優先順位を気にする必要はなく、同一業種内の「合計タグ → 区分の合算」の順序だけが意味を持つ。

| Extractor | 特徴 |
|---|---|
| `JgaapGeneral` | 一般事業会社に加え、建設・鉄道・電気・ガス・海運・電気通信・証券・特定金融・商品先物・投資業など**業種別の勘定科目を持つ業種もすべて**この1つで扱う（骨格が同じため）。売上・原価・販管費・営業費用のフォールバックが本体 |
| `JgaapBank` | 貸出金・預金など銀行専用タグ。**経常収益（`OrdinaryIncomeBNK`）と経常利益（`OrdinaryIncome`）は似た名前で桁が兆単位で違う** |
| `JgaapInsurance` | 有価証券・貸付金・保険契約準備金など保険専用タグ。**経常収益のタグ名が `OperatingIncomeINS`**（一般形式の営業利益 `OperatingIncome` と同系の名前で意味が違う） |
| `IfrsClassified` | 非流動負債はタクソノミ公式のタイポ（`NonCurrentLabilitiesIFRS`）を先に引く。のれん+無形は合算記法 |
| `IfrsLiquidity` | BSは合計系+現金。PL/CFは`IfrsClassified`と定数を共有（継承はしない。[03章](03_system_overview.md)） |

同じ入口から、形式によって違う科目が出てくる（キーが無い = 開示なし）。

| 科目コード | 武田薬品（ifrs_classified） | 三菱UFJ FG（jgaap_bank） |
|---|---|---|
| bs.assets | 15.5兆 | 431.7兆 |
| bs.current_assets | 3.09兆 | キーなし（銀行に流動区分がない） |
| bs.loans / bs.deposits | キーなし | 133.8兆 / 239.4兆 |
| pl.revenue | 4.5兆 | キーなし（銀行に売上高がない） |
| pl.ordinary_revenue | キーなし | 14.6兆 |

全科目のタグ対応と実測データは[07章](07_taxonomy_mapping.md)（**XBRLタグを触る作業の前に必読**）。

### 新しい業種・形式の追加手順

まず「骨格が一般事業会社と同じか」で分かれる。

- **骨格が同じ（流動/固定のBS + 売上・費用・営業利益のPL）** … 建設・鉄道・電気などと同じく `jgaap_general` に吸収する。`JgaapGeneral` のフォールバックリストに業種タグを足し、実測値でスペックを書き、[07章](07_taxonomy_mapping.md)の表を更新するだけ（形式は増やさない）
- **骨格が違う（保険・銀行のように流動/固定がなくPLが経常収益から始まる等）** … 新形式を追加する:
  1. 対象企業の有報XBRLを1件取得してタグを実測する
  2. Extractorクラスを追加（マッピング定数が本体）
  3. 判定表（`FormatDetector`）に1行 + 形式レジストリに定数とExtractor対応を追加
  4. 必要なら科目コードを追加
  5. 表示側のBuilderを追加（次節）
  6. 実測値でスペックを書き、[07章](07_taxonomy_mapping.md)の表を更新する

**DBマイグレーション・GraphQL・フロントの変更はなし**（[03章](03_system_overview.md)の層設計の狙いどおり）。既に `unsupported` で保存済みの有報は `rake 'ingestion:reingest_unsupported[from,to]'` で取り直す（[06章](06_development_operations.md)）。

## チャート生成

### チャート構造（取り決め2の中身）

バックエンドが「チャートの構造そのもの」まで組み立てて返す。フロント・Chrome拡張と共有する構造は次の2種類。

```
StackChart（BS/PL用。例は日本基準・一般のPL・黒字）
├ renderable: 描けるか
├ note: renderable=false のとき表示する説明文
└ bars: [                            # 借方・貸方の2本（債務超過時のみ3本目「債務超過」が加わる）
    { label: "借方",
      segments: [                    # 段の構成（key・数・順序）は形式ごとのBuilderが決める
        { key: "costOfSales",        # セグメントの識別子
          label: "売上原価",          # 表示ラベル
          amount: 描画高さの円（常に0以上）,
          signedAmount: 実値の円（ツールチップ用。損失は負）,
          ratio: 構成比%（spacer等の非表示セグメントはnull）,
          colorRole: "expense1" },   # 色の役割名。実際の色はフロントが解決する
        { key: "sga",             label: "販売一般管理費", amount, signedAmount, ratio, colorRole: "expense2" },
        { key: "operatingProfit", label: "営業利益",       amount, signedAmount, ratio, colorRole: "profit" } ] },
    { label: "貸方",
      segments: [
        { key: "revenue", label: "売上", amount, signedAmount, ratio, colorRole: "revenue" } ] } ]
```

```
WaterfallChart（CF用。5段の構成は全形式共通）
├ renderable: 描けるか
├ note: renderable=false のとき表示する説明文
└ steps: [
    { key: "cashBegin", label: "期首残",
      amount: 符号付きの円（-23兆もあり得る）,
      kind: "balance" },                                       # 残高: 0起点で描く
    { key: "operating", label: "営業CF", amount, kind: "flow" }, # 増減: 累積から浮かせる
    { key: "investing", label: "投資CF", amount, kind: "flow" },
    { key: "financing", label: "財務CF", amount, kind: "flow" },
    { key: "cashEnd",   label: "期末残", amount, kind: "balance" } ]
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

[03章](03_system_overview.md)で保存した行が、チャートになるまで。入力（単位: 百万円）:

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

残差項目のおかげで借方合計と貸方合計は常に一致し、赤字（税引前損失）は貸方に積んで高さを揃える。銀行・保険のBSも同じ考え方で、内訳科目が多すぎて全部は描けないため、主要科目（銀行: 現金預け金・貸出金・有価証券・預金 / 保険: 現金及び預貯金・有価証券・貸付金・保険契約準備金）だけタグで取り、「その他資産」「その他負債」を合計との残差で導出する。

### 実例2: 表示不可も正常系（東京海上のPL）

保険IFRSは収益が企業拡張タグのみで標準タグから取れない（実測は[07章](07_taxonomy_mapping.md)）。その場合も**カード全体を落とさず、取れなかったチャートだけ**説明文にする。

```json
{ "profitLoss":   { "renderable": false,
                    "note": "損益計算書: この企業のIFRS損益計算書は表示に対応していません。" },
  "balanceSheet": { "renderable": true, "bars": [...] },
  "cashFlow":     { "renderable": true, "steps": [...] } }
```

### 実例3: 業種で費用の構成が違うPL（日本基準・一般）

`jgaap_general` のPLは業種によって費用科目の組合せが違う。Builderは次の構成を順に試し、**借方合計（費用+営業利益）が売上と1割以内で合う最初の構成**で描く（開示された科目だけを積む）。

| 順 | 構成 | 当てはまる業種 |
|---|---|---|
| 1 | 売上原価・金融費用・販管費（あるものだけ） | 一般事業会社（原価+販管費）、証券（金融費用+販管費）、原価と販管費の内訳を営業費用と併記する鉄道連結など |
| 2 | 営業費用（一括） | 電気・特定金融・投資業など、原価と販管費に分けず一括開示する業種 |
| 3 | 売上原価 + 営業費用（原価控除後） | 商品先物取引業（営業収益−売上原価=営業総利益、−営業費用=営業利益） |

内訳を先に試すのは、内訳と一括を併記する企業で内訳（情報量が多い方）を捨てないため。逆に、原価が営業費用の内訳として併記される特定金融（内訳だけでは貸借が合わない）は2で描かれる。2を3より先に試すのは、営業費用が原価を含む合計の業種で原価を二重に積まないため。どれでも合わなければ描かない。

BSも同様に、固定資産は「有形・無形・投資その他の3分類の合計が固定資産に合うときだけ内訳」で描き、合わない業種（電気・鉄道・電気通信の単体など、業種別様式で3分類を持たない）は固定資産合計の1段で描く。

### Builderの分担と共通ルール

| 形式 | BS | PL | CF |
|---|---|---|---|
| `jgaap_general` | 流動/固定の4段（3分類を持たない業種は固定資産1段） | 費用（構成は業種で異なる。実例3）+営業利益 | 全形式共通（期首残→営業→投資→財務→期末残） |
| `jgaap_bank` | 主要科目+残差 | 経常収益/費用/利益（`PlJgaapFinancialInstitution`。保険と共通） | 同上 |
| `jgaap_insurance` | 主要科目+残差 | 銀行と共通 | 同上 |
| `ifrs_classified` | 流動/非流動 | 費用+税引前利益（残差つき） | 同上 |
| `ifrs_liquidity` | 現金+残差 | ifrs_classifiedと共通 | 同上 |
| `unsupported` | 「表示に対応していません」（renderable: false） | 同左 | Builderは共通だが科目が無いため常にrenderable: false |

形式によらない共通ルールは基底クラスに1回だけ書く（形式別Builderには書かせない）。

- **借方合計と貸方合計の乖離が1割を超えたら描かない**（誤ったグラフより出さない方を選ぶ）
- 必須科目が欠けたら描かない。銀行BSは預金がなければ、保険BSは保険契約準備金がなければ描かず（「預金0%の銀行」を出さない）、CFは5点すべて揃わなければ描かない
- 債務超過は3本目のバー「債務超過」を作り、透明な`spacer`で高さを合わせて描く
- 比率はBigDecimalで計算して小数1桁に切り捨て（「19.900000000000002%」や合計100%超を防ぐ）

## GraphQL API

GraphQLはフロントエンドとの間の問い合わせ言語で、RESTのようにURLごとに決まった形のデータを返すのではなく、**クライアントが「必要な項目」を宣言し、サーバがその形で返す**。サーバは「何をどんな型で問い合わせできるか」を**スキーマ**として定義し、スキーマ自体もAPIで取得できる（イントロスペクション。フロントの型生成が使う。[05章](05_frontend.md)）。

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
| `limit` 連動のコスト計算 | ライブラリ既定は引数を見ず `limit:1` と `limit:100` が同コストになるため、`limit` に比例した値（`limit / 2`）を複雑度に加算する |
| 金額は独自スカラ `Money`（JSON数値のまま返す） | 標準のBigInt型は文字列になり、Web・Chrome拡張の両方に変換処理が必要になる。日本企業の最大級の総資産400兆円=4×10^14はJavaScriptの安全整数9×10^15に収まる |
| 検索は提出日降順・CFパターンは科目行の符号で判定 | 絞り込み対象は `is_primary`（連結優先）の財務諸表だけ |

フィールドを増やすときは複雑度の実測値（一覧54 / Chrome拡張89 / 型生成のイントロスペクション187。上限400）に収まるか確認する。スキーマは `rake graphql:dump_schema` で`schema.graphql` に書き出してコミットする運用（手順は[06章](06_development_operations.md)）。

---

次章: [05. フロントエンド実装](05_frontend.md)
