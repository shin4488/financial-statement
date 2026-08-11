# 09. 用語集

このガイドと既存ドキュメントに登場する用語の索引。詳しい説明がある章をリンクで示す。

## 財務・会計

| 用語 | 意味 | 詳細 |
|---|---|---|
| 財務3表 | BS・PL・CFの総称。上場企業が開示する基本の財務書類 | [01章](01_financial_knowledge.md) |
| BS（貸借対照表） | ある時点の資産・負債・純資産の残高一覧。IFRSでは財政状態計算書 | [01章](01_financial_knowledge.md) |
| PL（損益計算書） | 1年間の収益・費用・利益の集計 | [01章](01_financial_knowledge.md) |
| CF（キャッシュフロー計算書） | 1年間の現金の増減を営業・投資・財務の3区分で示す書類 | [01章](01_financial_knowledge.md) |
| 営業利益 / 営業損失 | 本業の儲け。PLチャートの最終セグメント | [02章](02_product.md) |
| 経常収益 / 経常利益 | 銀行のPLで使う区分。名前が似ているが別物（収益は売上に相当、利益は儲け） | [05章](05_backend.md) |
| 債務超過 | 負債が資産を上回り純資産がマイナスの状態。3本目のバーで描画 | [02章](02_product.md) |
| 連結 / 単体 | 企業グループ全体の数値か、提出企業1社のみの数値か。連結を優先表示 | [01章](01_financial_knowledge.md) |
| 会計基準 | 財務諸表の作成ルール。日本基準・IFRS・米国基準 | [01章](01_financial_knowledge.md) |
| 流動性配列 / 分類様式 | IFRSのBSの2様式。流動/非流動に区分するか、しないか | [01章](01_financial_knowledge.md) |
| 有価証券報告書（有報） | 上場企業が事業年度ごとに提出する開示書類。データの源泉 | [01章](01_financial_knowledge.md) |
| 訂正有価証券報告書 | 有報の訂正版。同じ会計期間の上書きとして扱う | [01章](01_financial_knowledge.md) |
| CFパターン | 営業・投資・財務CFの正負の組合せ8種による分類（健全型など） | [02章](02_product.md) |

## 開示制度・データ形式

| 用語 | 意味 | 詳細 |
|---|---|---|
| EDINET | 金融庁の開示書類電子開示システム。API（v2）で機械取得できる | [01章](01_financial_knowledge.md) |
| docID | EDINETの書類管理番号（英数8桁）。書類1件を特定する | [01章](01_financial_knowledge.md) |
| docTypeCode | EDINETの書類種別。120=有報、130=訂正有報 | [01章](01_financial_knowledge.md) |
| EDINETコード | 提出者を特定する不変のID。企業マスタの自然キー | [01章](01_financial_knowledge.md) |
| 証券コード | 株式市場の銘柄コード。EDINET上5桁・UI上4桁 | [01章](01_financial_knowledge.md) |
| XBRL | 財務データの機械可読形式（XMLベース） | [01章](01_financial_knowledge.md) |
| fact | XBRLの最小単位。タグ+コンテキスト+値の組 | [01章](01_financial_knowledge.md) |
| タクソノミ | XBRLで使ってよいタグの辞書。金融庁が定義 | [01章](01_financial_knowledge.md) |
| `jppfs_cor` / `jpigp_cor` | 日本基準 / IFRSの財務諸表タグの名前空間 | [01章](01_financial_knowledge.md) |
| `jpdei_cor` / `jpcrp_cor` | DEI（書類メタ情報）/ 有報共通項目の名前空間 | [01章](01_financial_knowledge.md) |
| コンテキスト | factの「いつ・連結か単体か」を表す属性 | [01章](01_financial_knowledge.md) |
| DEI | 書類情報。会計基準・連結有無・会計期間などのメタ情報 | [01章](01_financial_knowledge.md) |
| 企業拡張タグ | 企業が独自定義するタグ。意味の保証がないため読まない | [01章](01_financial_knowledge.md) |

## このシステムの概念

| 用語 | 意味 | 詳細 |
|---|---|---|
| 形式（presentation_format） | 「会計基準 × 開示様式」の組合せ。`jgaap_general` など5種 | [02章](02_product.md) / [04章](04_system_overview.md) |
| 科目コード | `bs.assets` など全形式共通の40種の語彙。層の中央の契約 | [04章](04_system_overview.md) |
| 縦持ち | 科目を「1科目=1行」で保存するデータの持ち方 | [04章](04_system_overview.md) |
| 行がない = 開示なし | 未開示と0円を区別するデータ規約 | [04章](04_system_overview.md) |
| Extractor | 形式ごとのXBRLタグ→科目コードのマッピング | [05章](05_backend.md) |
| ChartBuilder | 科目コード→チャート構造の組み立て。形式ごとに存在 | [05章](05_backend.md) |
| チャート契約 | バックエンドが返すバー・セグメント構造の取り決め。フロントは並べ替えない | [06章](06_frontend.md) |
| colorRole | 色の役割名（`asset1` など15種）。バックエンドと両フロントの契約点 | [06章](06_frontend.md) |
| spacer | 債務超過バーの高さ合わせ用の透明セグメント | [05章](05_backend.md) / [06章](06_frontend.md) |
| renderable / note | チャートが描けるか・描けない理由の説明文。unsupportedは正常系 | [02章](02_product.md) |
| is_primary | 有報内で表示に使う財務諸表（連結優先）の印 | [04章](04_system_overview.md) |
| 冪等 | 何度実行しても同じ結果になる性質。再実行をリカバリ手段にする土台 | [05章](05_backend.md) / [08章](08_operations.md) |
| 旧系統（SecurityReport系） | 削除済みの旧実装。`security_reports`テーブルのみ凍結保管 | [04章](04_system_overview.md) |

## 技術

| 用語 | 意味 | 詳細 |
|---|---|---|
| SPA | ページ遷移せずJavaScriptが画面を書き換えるWebアプリ方式 | [03章](03_tech_prerequisites.md) |
| GraphQL | クライアントが必要な項目を宣言する問い合わせ言語 | [03章](03_tech_prerequisites.md) |
| イントロスペクション | GraphQLスキーマ自体をAPIで取得する仕組み。型生成に使う | [03章](03_tech_prerequisites.md) |
| graphql-codegen | スキーマからTypeScript型を自動生成するツール | [06章](06_frontend.md) |
| Apollo Client | GraphQLクライアント。取得とキャッシュを担当 | [03章](03_tech_prerequisites.md) |
| recharts | Reactのチャート描画ライブラリ | [03章](03_tech_prerequisites.md) |
| MUI | Reactコンポーネント集（Material Design） | [03章](03_tech_prerequisites.md) |
| Rails / ActiveRecord | バックエンドのフレームワークとORM | [03章](03_tech_prerequisites.md) |
| マイグレーション | DBスキーマの変更をコードで管理する仕組み | [03章](03_tech_prerequisites.md) |
| Sidekiq / sidekiq-cron | 非同期ジョブ基盤と、そのスケジュール実行拡張 | [03章](03_tech_prerequisites.md) |
| figaro | 環境変数を `config/application.yml` で管理するgem | [05章](05_backend.md) |
| Sentry | エラー監視サービス。運用の通知先 | [08章](08_operations.md) |
| nginx / リバースプロキシ | リクエストの振り分け役。開発・本番両方の入口 | [03章](03_tech_prerequisites.md) |
| Docker Compose | 開発環境を5サービスまとめて起動するツール | [03章](03_tech_prerequisites.md) |
| git submodule | リポジトリに別リポジトリを組み込む仕組み。2段階コミットが必要 | [03章](03_tech_prerequisites.md) / [07章](07_development.md) |
| rsync | ファイル同期コマンド。本番デプロイの転送手段 | [08章](08_operations.md) |
| puma | Railsのアプリケーションサーバ | [03章](03_tech_prerequisites.md) |
| Certbot | Let's EncryptのTLS証明書を自動管理するツール | [08章](08_operations.md) |
