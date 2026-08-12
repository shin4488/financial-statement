# 04. システム全体像と設計

リポジトリの構成、このアプリ固有の難しさ、それをどう解いているか（層の設計とデータモデル）、
データが流れる道筋。この章を読むと「どこで何が・なぜそうなっているか」がつかめ、
[05章](05_backend.md)・[06章](06_frontend.md)は各論として読めるようになる。

## リポジトリ構成

[03章](03_tech_prerequisites.md)で見たとおり3リポジトリ構成で、親リポジトリの
ディレクトリは次の役割を持つ。

| パス | 内容 |
|---|---|
| `application/backend` | Rails APIサーバ（別リポジトリのsubmodule） |
| `application/frontend` | React SPA（別リポジトリのsubmodule） |
| `web/` | nginx（リバースプロキシ）の設定 |
| `database/` / `cache/` | PostgreSQL / RedisのDocker設定 |
| `docs/` | ドキュメント（このガイド・改善バックログ） |
| `docker-compose.yml` | 開発環境の全体起動 |
| `.github/workflows/` | CI（submodule参照の整合性チェック） |
| `.claude/skills/` | 定型作業の手順書（デプロイ・日次確認・PR運用・リリース） |

## 開発環境の5サービス

`docker compose up` で以下が起動する。セットアップの具体的手順は[ルートREADME](../../README.md)が正。

```mermaid
flowchart LR
    Browser["ブラウザ<br>localhost:10000"] --> Web
    subgraph "Docker Compose"
        Web["web（nginx）"] -->|"/ へのアクセス"| Front["appfront（React devサーバ）"]
        Web -->|"/api へのアクセス"| Server["appserver（Rails + Sidekiq）"]
        Server --> Database[("database<br>PostgreSQL")]
        Server -.-> Cache[("cache<br>Redis")]
    end
    Browser2["動作確認用<br>localhost:20000"] --> Server
```

## このアプリ固有の難しさ

やりたいことは「有報の数字をグラフにする」だけだが、[01章](01_financial_knowledge.md)で見た
とおり、同じ「資産合計」でも企業によってXBRLのタグ名が違う。

```
武田薬品（IFRS）      jpigp_cor:AssetsIFRS
三菱UFJ（日本基準）    jppfs_cor:Assets
トヨタ（日本基準）      jppfs_cor:Assets      ← 銀行と同じタグ
```

しかもタグ名だけの違いではなく、財務諸表の構造自体が変わる。

| | 一般事業会社 | 銀行 | IFRS |
|---|---|---|---|
| BSの区分 | 流動 / 固定 | 区分なし（貸出金・預金） | 流動 / 非流動 |
| PLのトップライン | 売上高 | 経常収益 | 売上収益 |
| 利益の段階 | 営業→経常→当期 | 経常→当期 | 経常利益が無い |

この差異を素直に持ち込むと、テーブルは全形式の全科目を横に並べた形になり、
グラフ部品は形式ごとの専用コンポーネントに分かれていく。すると新しい形式（例: 保険）を
1つ足すだけで**全層を触る**ことになる。

```
DBにカラム追加 → 取込に分岐追加 → APIに項目追加 → フロントに部品追加 → Chrome拡張にも複製
```

実際、旧実装ではIFRS企業の連結が0円で保存されて表示できない、という形でこの問題が起きていた。

## 解き方: 変わるものを層の端に寄せる

何が変わり何が変わらないかを分けて考える。

| | 具体例 |
|---|---|
| 形式ごとに変わるもの | XBRLのタグ名、BSの段の構成、PLの利益段階 |
| 形式によらず変わらないもの | 「資産 = 負債 + 資本」という関係、積み上げバー2本で貸借を表す見せ方 |

変わらないもの（**科目コード** `bs.assets` など全形式共通の40種の語彙）を中央に置き、
変わるものを両端に寄せる。

```mermaid
flowchart LR
    X["XBRLタグ<br>（形式ごとに違う）"] -->|Extractor| C["科目コード<br>（全形式共通・40種）"]
    C -->|ChartBuilder| Chart["チャート構造<br>（形式ごとに違う）"]
    Chart -->|GraphQL| F["フロントエンド<br>（形式を知らない）"]
```

これをコードに落とすと4層になり、依存は一方向で逆流させない。

| 層 | 知ってよいこと | 知ってはいけないこと |
|---|---|---|
| ① 取込（`Ingestion::`） | XBRLのタグ名・タクソノミ・形式判定 | グラフの見た目・色・段の順序 |
| ② 保存（`Disclosure::`） | 科目コードの一覧 | XBRLのタグ名 / グラフの構造 |
| ③ 表示（`Charts::` / GraphQL） | 科目コード・グラフの構成・色の役割 | XBRLのタグ名 |
| ④ フロントエンド | チャート構造の形（bars / segments） | 科目名も会計基準も一切 |

この表が実装で迷ったときの判断基準になる。たとえば「フロントで銀行だけ色を変えたい」と
思ったら、それは④に③の知識を持ち込む変更なので、代わりに③で色の役割（`colorRole`）を
割り当て直す。

### 層の間の2つの契約

層を分けただけでは足りず、層の間で受け渡すデータの形を固定している。

- **契約1: 科目コード**（①→②→③）。命名は `<財務諸表>.<英名スネークケース>`（`bs.` 18 / `pl.` 17 / `cf.` 5）。
  定義はRubyの定数 `item_codes.rb` だけに置き、DBにマスタテーブルは作らない
  （コードと利用箇所は必ず同時に変わるため、grepとレビューが効く方が安全）。
  「Extractorが使うコード ⊆ 定義」はspecで機械検証している
- **契約2: チャート構造**（③→④）。積み上げバーの中身までバックエンドが組み立てて返す。
  `segments` が固定キーを持たない配列なので、銀行BSの4段もIFRSの2段も同じ型で表せ、
  形式が増えてもフロントは変更不要（構造の詳細と実例は[05章](05_backend.md)）

### 分岐ではなく登録表で形式を増やす

形式ごとの差異を `if` や継承で書くと、形式が増えるたびに既存コードを触ることになる。
ここでは「形式 → クラス」のハッシュ登録に統一し、新形式はクラス1つ+表に1行の追加だけで
済ませる。似た形式（IFRSの2様式）でも**継承はさせない**。片方の修正がもう片方に波及して、
形式ごとに独立して保守できる利点が消えるためで、マッピング定数の重複はあえて許容する。
逆に形式によらない共通ロジック（債務超過・貸借検証・比率計算）は基底クラスに1回だけ書く。

設計が効いているかは「新形式の追加で触るファイル」で確認できる。

| 層 | 新形式（例: 保険）追加時の作業 |
|---|---|
| ① 取込 | Extractorクラスを1つ追加 + 判定表と登録表に1行ずつ |
| ② 保存 | **なし**（マイグレーション不要） |
| ③ 表示 | Builderクラスを1〜2つ追加 + 登録表に1行 |
| ④ フロント / Chrome拡張 | **なし** |

## データモデル

設計を決めているのは開示実務の4つの事実。

| 業務上の事実 | データモデルへの反映 |
|---|---|
| 訂正有報が、同じ会計期間のデータを別書類として上書きしに来る | 有報の自然キーを書類IDでなく「企業+会計期間」にする |
| 企業は社名を変えるが、過去の有報は提出当時の名前で読みたい | 企業名を2箇所に持つ（下記） |
| 開示しない科目がある。「0円」とは意味が違う | 「行がない = 開示なし」の規約（下記） |
| IFRS企業でも単体財務諸表は日本基準でタグ付けされる（実測6社すべて） | 会計基準・表示形式を「有報」でなく「財務諸表」の属性にする。有報1通の中に `ifrs_classified`（連結）と `jgaap_general`（単体）が同居する |

```mermaid
erDiagram
    companies ||--o{ reports : "1社に複数の有報"
    reports ||--o{ financial_statements : "連結・単体で最大2つ"
    financial_statements ||--o{ financial_statement_items : "科目ごとに1行"

    companies {
        string edinet_code "自然キー（不変）"
        string stock_code "証券コード（5桁）"
        string company_japanese_name "最新の社名"
    }
    reports {
        string edinet_document_id "書類ID（訂正有報で上書きされる）"
        date fiscal_year_start_date "会計期間（自然キーの一部）"
        date fiscal_year_end_date "会計期間（自然キーの一部）"
        date filing_date "提出日"
        int accounting_standard "有報全体の会計基準"
        string company_name_ja "提出時点の社名"
    }
    financial_statements {
        int consolidation_type "連結/単体"
        int accounting_standard "財務諸表ごとの会計基準（有報と異なり得る）"
        string presentation_format "形式（jgaap_general等）"
        bool is_primary "表示に使う方（連結優先）"
    }
    financial_statement_items {
        string item_code "科目コード（bs.assets等）"
        bigint amount "金額（円）"
    }
```

### 企業名は2箇所に持つ

| 置き場所 | 内容 | 更新ルール |
|---|---|---|
| `companies.company_japanese_name` | 最新の企業名 | その企業の**最新会計期**の有報を取り込んだときだけ更新（過去年度の取込で巻き戻さない） |
| `reports.company_name_ja` | 提出時点の企業名 | その有報を取り込むたび（訂正有報も上書き） |

実例（NTT。2025年に日本電信電話から社名変更）: 2024年3月期の有報は
「日本電信電話株式会社」のまま表示され、2026年3月期は「NTT株式会社（旧会社名 日本電信電話株式会社）」
という提出書類の表記で表示される。マスタは最新名だけを持つ。

### 規約: 「行がない = 開示なし」

| XBRLから値が | どうするか |
|---|---|
| 取れた | 行を作る（0円なら `amount = 0` の行を作る） |
| 取れない | 行を作らない（NULLも0も保存しない） |

これで「0円」と「開示なし」の区別がつく。横持ちだった旧テーブルではIFRS企業の全カラムが
0で埋まり、0なのか未開示なのか判別できなかった。

保存された行の実例（武田薬品・IFRS連結。単位: 円）:

| item_code | amount | 由来 |
|---|---|---|
| bs.assets | 15,511,506,000,000 | `jpigp_cor:AssetsIFRS` |
| bs.goodwill_and_intangibles | 9,228,358,000,000 | のれん+無形の2タグをExtractorが合算 |
| pl.profit_before_tax | -142,355,000,000 | 赤字は負の値のまま保存 |

`pl.gross_profit` の行は存在しない（武田は売上総利益を開示していないため）。
このデータが[05章](05_backend.md)で抽出され、チャートになる姿まで追える。

このほか旧実装の `security_reports` テーブルが凍結保管されている（コードからの参照はゼロ。
経緯は[09章](09_legacy_cleanup.md)）。

## 処理の流れ

処理は互いに独立した2系統に分かれ、DBのテーブル定義と科目コードだけを共有する。

```mermaid
flowchart LR
    subgraph 取込系["取込系（毎日2:00のバッチ）"]
        EDINET["EDINET API"] --> Ingest["取込パイプライン"]
    end
    Ingest --> DB[("PostgreSQL")]
    subgraph 参照系["参照系（リクエストのたび）"]
        DB2["検索 + チャート組み立て"] --> GQL["GraphQL応答"]
    end
    DB --> DB2
    GQL --> SPA["React SPA"]
```

### 取込系

```mermaid
sequenceDiagram
    participant Cron as sidekiq-cron（毎日2:00）
    participant Svc as 取込サービス
    participant Edinet as EDINET API
    participant DB as PostgreSQL

    Cron->>Svc: 日次ジョブ起動（対象は前日提出分）
    Svc->>Edinet: 書類一覧を取得（有報・訂正有報のみ）
    loop 書類ごと（逐次・1秒間隔）
        Svc->>Edinet: XBRLをダウンロード
        Svc->>Svc: パース → 検証 → 形式判定 → 科目抽出
        Svc->>DB: 保存（1有報 = 1トランザクション）
    end
```

- 深夜2:00に実行するのは、当日分の提出が出そろうのを待つため（対象は前日提出分）
- EDINET APIの403対策で並列化せず、書類間に1秒の間隔を置く
- 失敗は「書類単位」「日単位」で隔離され、1件の失敗が全体を止めない。
  自動リトライは持たず、**全処理を冪等（何度実行しても同じ結果）にして再実行で回復する**

### 形式判定

[02章](02_product.md)の「形式」（会計基準 × 様式）は、取込時に次のフローで決まる。

```mermaid
flowchart TB
    Start{"会計基準はどれか<br>（DEIタグ AccountingStandardsDEI）"} -->|Japan GAAP| Ind{"業種コードはどれか"}
    Start -->|IFRS| Tag{"流動資産タグ<br>CurrentAssetsIFRS があるか"}
    Start -->|US GAAP| Unsup2["unsupported"]
    Ind -->|"なし / cte（一般）"| General["jgaap_general"]
    Ind -->|"bnk（銀行）"| Bank["jgaap_bank"]
    Ind -->|"その他（INS=保険 等）"| Unsup1["unsupported"]
    Tag -->|ある| Cls["ifrs_classified"]
    Tag -->|ない| Liq["ifrs_liquidity"]
```

- IFRSの2様式はDEIでは区別できず、タグの実在で判定する（根拠の実測は[08章](08_taxonomy_mapping.md)）
- 未知の業種コードは安全側に倒して `unsupported` にする（誤ったグラフを出さない）
- **単体財務諸表は常に日本基準として扱う**（[01章](01_financial_knowledge.md)の
  「IFRS企業でも単体は日本基準タグ」の実装反映）

### 参照系

`POST /graphql` の1本だけ。検索とチャート組み立てを行い、**チャートの構造そのもの**
（バーとセグメントの並び）をJSONで返す。中身は[05章](05_backend.md)で説明する。

---

次章: [05. バックエンド](05_backend.md) / [06. フロントエンド実装](06_frontend.md)
