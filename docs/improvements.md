# 改善バックログ — DX / SEO・Web / AI活用

リポジトリ調査(2026-07)に基づく改善候補。**即対応できたものは対応済み**とマークし、
それ以外は「現状・意図 → 作業手順」の形で、着手時にそのまま手を動かせる粒度で書く。

前提知識: このリポジトリは親リポジトリ + submodule 2つ（application/backend, application/frontend）で
構成される。**backend/frontend内のファイル変更はそれぞれのリポジトリでのコミットが必要**で、
CIワークフローも各submoduleリポジトリ側に置く（詳細は [CLAUDE.md](../CLAUDE.md)）。

## 対応済み（今回実施）

| 項目 | 内容 |
|---|---|
| ✅ meta description / canonical | `frontend/public/index.html` に `<meta name="description">`・`<link rel="canonical">`・`og:type`・`og:locale`・`twitter:title` を追加 |
| ✅ 構造化データ | index.html に WebSite の JSON-LD を追加 |
| ✅ sitemap.xml | `frontend/public/sitemap.xml` 新規作成 + `robots.txt` に `Sitemap:` 行を追加 |
| ✅ CLAUDE.md | リポジトリ直下に作成（AIエージェント向けコンテキスト） |

---

## 1. 開発者体験（DX）

### 1-1. シークレット管理のサンプルファイル整備

- **現状**: 環境依存の設定ファイルはgit管理外で適切に運用されている。
  ただしサンプルファイルがないため、新環境構築時・他の開発者やAIエージェントの作業時に、
  必要な設定項目がコードをgrepしないと分からない
- **意図**: セットアップの再現性 + 誤って実値をコミットする事故の予防線
  （sampleがあると「実ファイルはsampleをコピーして作る」動線が自然になる）

**手順**（backendリポジトリ・30分）:

1. git管理外の設定ファイルと同じ場所に `.sample` サフィックスのファイルを作成してコミットする。
   設定項目名はコード内の `ENV[...]` 参照を洗い出して列挙し、**値はすべてダミーにする**
   （実値・実URL・アカウント識別子の類は一切書かない。各値の入手方法は
   「どのサービスで発行するか」程度の一般的な説明コメントに留める）
2. READMEのセットアップ手順に「sampleを同名（サフィックスなし）でコピーして各自の値を設定する」を追記
3. コミット前にsample内に実値が混入していないことを目視確認する

あわせて運用ルールとして、**git管理されるファイル（このドキュメント・README・CLAUDE.md含む）には
設定の「項目名と入手方法」までを書き、実値や実環境の識別子は書かない**ことを徹底する。

### 1-2. CI（GitHub Actions）

- **現状**: backend/frontend/親リポジトリともワークフローなし。lint・型チェック・ビルドが手元任せ
- **意図**: 「フロントだけ直してビルドが壊れる」「submodule参照の更新漏れ」の自動検知

**手順**:

1. **frontendリポジトリ** に `.github/workflows/ci.yml` を作成:
   ```yaml
   name: CI
   on: [push, pull_request]
   jobs:
     check:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-node@v4
           with: { node-version-file: ".nvmrc", cache: "npm" }  # .nvmrcがなければ現行のnodeバージョンで作る
         - run: npm ci
         - run: npx tsc --noEmit
         - run: npx eslint 'src/**/*.{ts,tsx}'
         - run: npx prettier --check 'src/**/*.{ts,tsx}'
         - run: npm run build
           env: { CI: "false" }  # CRAはCI=trueだとwarningをerror扱いする。まずは通す設定で始め、後で外す
   ```
2. **backendリポジトリ** に同様のワークフロー（1-3, 1-4完了後に有効化）:
   ```yaml
   name: CI
   on: [push, pull_request]
   jobs:
     check:
       runs-on: ubuntu-latest
       services:
         postgres:
           image: postgres:15
           env: { POSTGRES_USER: ci, POSTGRES_PASSWORD: ci, POSTGRES_DB: app_test }
           ports: ["5432:5432"]
           options: --health-cmd pg_isready --health-interval 5s
       steps:
         - uses: actions/checkout@v4
         - uses: ruby/setup-ruby@v1
           with: { bundler-cache: true }  # .ruby-version(3.2.2)を自動参照
         - run: bundle exec rubocop
         - run: bundle exec rspec
           env:
             POSTGRES_HOST_NAME: localhost
             POSTGRES_PORT: "5432"
             POSTGRES_USER_NAME: ci
             POSTGRES_PASSWORD: ci
             POSTGRES_DATABASE_NAME: app_test
             EDINET_API_KEY: dummy  # テストは実APIを叩かない（webmockで遮断・1-3参照）
   ```
3. **親リポジトリ** にsubmodule整合性チェック `.github/workflows/submodules.yml`:
   ```yaml
   name: submodule-check
   on: [push, pull_request]
   jobs:
     check:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
           with: { submodules: true }
         - name: submoduleの参照コミットが各リポジトリのmainに含まれるか検証
           run: |
             git submodule foreach '
               git fetch origin main --quiet
               git merge-base --is-ancestor HEAD origin/main \
                 || { echo "::error::$name はmainに存在しないコミットを参照しています"; exit 1; }
             '
   ```

### 1-3. バックエンドのテスト基盤

- **現状**: テストフレームワーク未導入（Gemfileにrspec/minitestなし）
- **意図**: XBRLパースは回帰が起きやすい（タクソノミのタイポ・業種ゆれ・コンテキスト取り違え）。
  実XBRLをfixture化した再現テストが最も費用対効果が高い

**手順**（backendリポジトリ・2〜3日）:

1. Gemfileに追加して `bundle install`:
   ```ruby
   group :development, :test do
     gem "rspec-rails"
     gem "factory_bot_rails"
   end
   group :test do
     gem "webmock"  # テスト中の実HTTP通信を遮断
   end
   ```
2. `bin/rails generate rspec:install` を実行。`spec/rails_helper.rb` に追記:
   ```ruby
   require "webmock/rspec"
   WebMock.disable_net_connect!(allow_localhost: true)  # EDINETへの誤アクセスをテストで即検知
   ```
3. fixture用XBRLの取得スクリプト `spec/support/fixtures/download_xbrl.rb` を作成
   （コミットするのはスクリプトのみ。XBRL自体は初回に各自ダウンロード。
   リポジトリにXBRLを直接コミットしてもよい—公開情報であり1ファイル数MB×6）:
   ```ruby
   # 使い方: EDINET_API_KEY=xxx bundle exec ruby spec/support/fixtures/download_xbrl.rb
   # docs/zero-base-redesign/01 の検証済み6社を spec/fixtures/xbrl/ に保存する
   DOC_IDS = %w[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO]
   # （中身は Edinet::Client#download_xbrl と同じ処理。既存ならスキップ）
   ```
4. 最初のスペックは「Readerのスナップショット」から書く（最小工数で最大の回帰検知）:
   ```ruby
   # spec/repositories/security_report/reader_repository_spec.rb
   RSpec.describe SecurityReport::ReaderRepository do
     it "IFRS企業（武田薬品）を読める" do
       result = described_class.new("spec/fixtures/xbrl/S100YB5L.xbrl").read
       expect(result[:accounting_standard]).to eq "ifrs"
       # 期待値は docs/zero-base-redesign/01_xbrl_format_research.md の実測表から転記
       expect(result[:non_consolidated_statement][:current_asset]).to eq 602_273_000_000
     end
   end
   ```
5. CI（1-2）のrspecステップを有効化

### 1-4. Lint/Format（バックエンド）

**手順**（backendリポジトリ・半日）:

1. Gemfile: `gem "rubocop-rails-omakase", require: false, group: [:development, :test]`
2. `.rubocop.yml` を作成:
   ```yaml
   inherit_gem: { rubocop-rails-omakase: rubocop.yml }
   ```
3. `bundle exec rubocop -A` で自動修正 → 差分をレビューして1コミットに分離
   （ロジック変更が混ざらないよう、このコミットには自動修正以外を入れない）
4. 自動修正できない違反が多い場合は `bundle exec rubocop --auto-gen-config` で
   `.rubocop_todo.yml` を生成し「現状は許容・新規コードから適用」で開始
5. CI（1-2）のrubocopステップを有効化

### 1-5. GraphQLスキーマのコミットとcodegenのCI検証

- **現状**: フロントの `npm run compile`（graphql-codegen）がバックエンド起動を要求する
- **意図**: スキーマとフロント型のズレ検知 + バックエンド起動なしのフロント開発

**手順**:

1. backend: スキーマダンプのrakeタスクを追加:
   ```ruby
   # lib/tasks/graphql.rake
   namespace :graphql do
     task dump_schema: :environment do
       File.write("schema.graphql", GraphQL::Schema::Printer.print_schema(FinancialStatementSchema))
     end
   end
   ```
   `bundle exec rake graphql:dump_schema` を実行し `schema.graphql` をコミット
2. backend CI に「ダンプして未コミット差分があれば失敗」を追加:
   ```yaml
   - run: bundle exec rake graphql:dump_schema && git diff --exit-code schema.graphql
   ```
3. frontend: `codegen.ts` の `schema:` をURLからファイルパスに変更
   （submodule構成なら相対パス `../backend/schema.graphql` が使える）
4. frontend CI に `npm run compile && git diff --exit-code src/__generated__` を追加
   （スキーマ変更を取り込まず生成物が古いままのPRを検知）

### 1-6. セットアップの一本化

- **現状**: READMEがRails雛形のまま。起動手順が散在（docker_setup.sh / docker-compose / 手動rbenv）
- **意図**: 新環境（新PC・他の開発者・AIエージェント）が10分で画面に財務データを出せる状態

**手順**（親リポジトリ・1日）:

1. ルート `README.md` を書き換え。必須セクション:
   - アプリ概要とアーキテクチャ図（CLAUDE.mdの構成図を流用）
   - 初回セットアップ: `git clone --recursive` → application.yml作成（1-1のsample参照）→ `docker compose up`
   - データ投入: 下記シードスクリプトの実行方法
   - 各URL（web:10000 / api:20000）と動作確認方法
2. 開発用シードスクリプトを backend に追加:
   ```ruby
   # lib/tasks/dev_seed.rake — 検証済み6社の有報を取り込む（EDINET APIキー必須）
   namespace :dev do
     task seed_reports: :environment do
       doc_ids = %w[S100YB5L S100YB25 S100YCP3 S100XTNW S100YLS8 S100YJQO]
       SecurityReport::SubscriberService.subscribe_by_target_document_ids(target_document_ids: doc_ids)
     end
   end
   ```
3. `docker compose exec appserver bundle exec rake dev:seed_reports` をREADMEに記載

### 1-7. submodule運用の見直し（検討）

- **現状**: 変更のたびに「submoduleでコミット→親でハッシュ更新コミット」の二度手間。
  履歴も "update submodule" が多くを占める
- **意図**: 個人開発でsubmoduleの分離メリット（別権限・別チーム）が活きていないならmonorepo化で摩擦が減る

**手順**（判断→実施で半日〜1日）:

1. まず判断: 以下のいずれかに該当するならsubmodule維持、どれもなければmonorepo化
   - backend/frontendを別の公開範囲・別のCI/CD権限で運用したい
   - 他プロジェクトからこれらを部品として参照している
2. monorepo化する場合（親リポジトリで実施）:
   ```bash
   # 履歴ごと取り込む。prefixは現行と同じパスにするとデプロイ設定の変更が最小
   git rm application/backend application/frontend && git commit -m "remove submodules"
   git subtree add --prefix=application/backend  <backendリポジトリURL>  main
   git subtree add --prefix=application/frontend <frontendリポジトリURL> main
   ```
3. `.gitmodules` 削除、CI（1-2）を親リポジトリの `paths:` フィルタ付きワークフローに統合
4. 旧リポジトリはREADMEに「monorepoへ移行済み」と書いてアーカイブ

---

## 2. SEO・Webサイト品質

### 2-1. 企業別URLの導入【SEO効果が最も大きい】

- **現状**: 全機能が `/` の1URL。検索条件もURLに乗らない。Googleから見ると「1ページのサイト」で、
  「〇〇(企業名) 財務諸表」等の個別クエリの受け皿がない
- **意図**: 上場企業約4,000社 × 会計年度分のロングテール検索流入の土台

**手順**（frontendリポジトリ中心・2〜3日）:

1. ルート定義（`App.tsx`）:
   ```tsx
   <Routes>
     <Route path="/" element={<FinancialStatementList />} />
     <Route path="/companies/:stockCode" element={<CompanyPage />} />
   </Routes>
   ```
2. `CompanyPage` は既存一覧の実装を流用: `useParams()` の stockCode を既存GraphQLクエリの
   `stockCodes: [stockCode]` に渡すだけ（バックエンド変更不要。全期分が返る）
3. 一覧カードの企業名を `<Link to={`/companies/${stockCode}`}>` にする
4. `react-helmet-async` を導入し、ルートごとにtitle/description/canonicalを設定:
   ```tsx
   <Helmet>
     <title>{`${companyName}(${stockCode})の財務三表・キャッシュフロー | investee`}</title>
     <meta name="description" content={`${companyName}の貸借対照表・損益計算書・キャッシュフローを図解。…`} />
     <link rel="canonical" href={`https://investee.info/companies/${stockCode}`} />
   </Helmet>
   ```
5. 企業ページに `Corporation` のJSON-LD（name, tickerSymbol）を出力
6. 検索条件のURLクエリ同期: フィルタ変更時に `setSearchParams({ codes, ocf, ... })`、
   初期化時にURLから復元（ゼロベース再設計 [05](zero-base-redesign/05_frontend.md) §9 と同じ方式）
7. SPAの直リンク対応: nginx（`web/`）に `try_files $uri /index.html;` があることを確認
   （なければ追加。ないと `/companies/7203` 直アクセスが404になる）

### 2-2. プリレンダリング / SSR

- **現状**: CRAのCSR。クローラの初期HTMLは空の `<div id="root">`。SNSカードも全URL共通
- **意図**: 2-1の企業ページを確実・高速にインデックスさせ、企業ごとのOGPを出す

**手順**（Next.js移行案・1〜2週間。ゼロベース再設計のフロント刷新と同時実施を推奨）:

1. `npx create-next-app`（App Router・TypeScript）で新規プロジェクトを frontend リポジトリの
   `next/` に作成（並行稼働のため既存 `src/` は残す）
2. 移植マッピング:
   | 現行 | Next.js |
   |---|---|
   | `public/index.html` のmeta群 | `app/layout.tsx` の `metadata` |
   | `pages/financialStatementList` | `app/page.tsx`（一覧・CSRのままでよい） |
   | 企業ページ（2-1） | `app/companies/[stockCode]/page.tsx`（**SSR対象はここだけ**） |
   | チャートコンポーネント | そのまま移植（rechartsはclient component: `'use client'`） |
   | Apollo Client | サーバ側は `@apollo/client` のRSC統合 or 単純に `fetch` でGraphQL POST |
3. 企業ページは `generateMetadata` でtitle/description/OGPを動的生成し、
   ISR（`revalidate: 86400`）でキャッシュ。generateStaticParamsは使わない
   （4,000社の全ビルドは不要。アクセス時生成+日次再検証で十分）
4. デプロイ: 現行nginx+静的配信からNode実行環境が必要になる。
   docker-composeの `appfront` をNext.jsのstandalone出力（`output: 'standalone'`）に差し替え
5. 切替: nginxのルーティングを新アプリに向け、Search Consoleでインデックス状況を2週間監視
6. **より軽い代替案**（Next.jsを避けたい場合）: 2-1完了後、`react-snap` 等のビルド時プリレンダは
   企業数分のビルド時間爆発で不向き。実用的なのは「トップだけ静的メタ改善（対応済み）+
   企業ページはGooglebotのJSレンダリングに任せる」で、まず2-1+2-3だけ入れて
   Search Consoleの実測を見てからSSR投資を判断するのも合理的

### 2-3. 動的sitemap

- **現状**: 静的sitemap.xml（トップのみ・今回追加）
- **意図**: 2-1の企業別URLをクローラに全量通知

**手順**（backend + web・半日。2-1が前提）:

1. backendにコントローラを追加:
   ```ruby
   # config/routes.rb
   get "/sitemap.xml", to: "sitemaps#show"

   # app/controllers/sitemaps_controller.rb
   class SitemapsController < ApplicationController
     def show
       # lastmod = その企業の最新有報の提出日。クローラに再訪の必要性を伝える
       companies = Company.joins(:security_reports)
                          .group(:id).select("companies.*, MAX(security_reports.filing_date) AS last_filed")
       xml = build_sitemap_xml(companies)  # トップ + /companies/{4桁コード} を列挙
       render xml: xml
     end
   end
   ```
2. nginx（`web/sites-enabled`）に `/sitemap.xml` → appserver へのproxy設定を追加
   （現状 `/graphql` などAPI系のみproxyしているはずなので1 location追加）
3. `frontend/public/sitemap.xml` を削除し、`robots.txt` の `Sitemap:` はそのまま
   （URLは変わらないため）
4. Search Consoleでsitemapを再送信し、カバレッジを確認

### 2-4. パフォーマンス / Core Web Vitals

**手順**（frontendリポジトリ・1日）:

1. 現状把握: `npx source-map-explorer build/static/js/*.js` でバンドル内訳を確認
   （recharts・MUI・firebaseが主要因のはず）
2. ルート分割: 2-1のルートを `React.lazy(() => import('./CompanyPage'))` + `<Suspense>` に
3. firebaseの初期化を遅延（analyticsは初回描画後で十分）: `requestIdleCallback` 内でimport
4. Lighthouse CIをfrontend CIに追加:
   ```yaml
   - run: npm run build && npx @lhci/cli autorun --collect.staticDistDir=./build
   ```
   予算(assertion)は最初は警告のみ運用にし、実測値が安定してからfailに切替
5. web-vitals（導入済み）の計測値をFirebase Analyticsに送るコードを有効化し、実ユーザー値を蓄積

### 2-5. コンテンツ面のSEO（3-3のAI生成と連動）

- **意図**: チャートのみのページはテキストが薄く、検索エンジンに内容が伝わらない。
  企業ページに「直近期の要点」の説明文を載せる
- **手順**: 3-3で生成・保存したコメントを、企業ページのチャート上部に表示するだけ
  （`commentary` フィールドをGraphQLに追加）。コメント未生成の企業は非表示（劣化戦略）。
  ページ下部に「データ出典: EDINET（金融庁）」の明記も追加（E-E-A-T対策・半日）

---

## 3. AI活用

### 3-1. Claude Code向けコンテキスト整備【対応済み】

CLAUDE.md作成済み。運用ルール: 設計変更時はCLAUDE.mdとdocs/の更新を同じPRに含める。

### 3-2. PR自動レビュー

- **意図**: 個人開発でレビュアー不在。XBRL周りはタグ名typo等の機械的な見落としが起きやすい

**手順**（backend/frontend各リポジトリ・30分ずつ）:

1. リポジトリのSecretsに `ANTHROPIC_API_KEY` を登録
2. `.github/workflows/claude-review.yml`:
   ```yaml
   name: claude-review
   on:
     pull_request: { types: [opened, synchronize] }
   jobs:
     review:
       runs-on: ubuntu-latest
       permissions: { contents: read, pull-requests: write }
       steps:
         - uses: anthropics/claude-code-action@v1
           with:
             anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
             prompt: "/review"
   ```
3. CLAUDE.md（リポジトリごとに簡易版を配置）に「レビュー観点」を書いておくと精度が上がる:
   XBRLタグ名は docs/zero-base-redesign/01 の実測表と一致するか・コンテキストの
   Instant/Duration取り違えがないか・「開示なし=行なし」規約を破っていないか等

### 3-3. 財務コメントの自動生成（SEOコンテンツ兼用）

- **意図**: 可視化に「読み」を添えて価値を上げ、2-5のテキスト不足も解消

**手順**（backendリポジトリ・2〜3日）:

1. テーブル追加:
   ```ruby
   create_table :report_commentaries, comment: "有報サマリコメント（AI生成）" do |t|
     t.references :security_report, null: false, index: { unique: true }
     t.text :body, null: false, comment: "生成された解説文（プレーンテキスト150-200字）"
     t.string :model, null: false, comment: "生成に使ったモデルID（再生成判断・品質追跡用）"
     t.timestamps
   end
   ```
2. Gemfile: `gem "anthropic"`。生成サービスを追加:
   ```ruby
   class Commentary::GeneratorService
     MODEL = "claude-haiku-4-5-20251001"  # 定型要約タスクのためコスト最小のモデルで十分
     SYSTEM = <<~PROMPT
       あなたは財務データの要約者です。与えられた財務数値から事実のみを150字程度の日本語で記述してください。
       禁止: 投資推奨・将来予測・「良い/悪い」等の評価語。数値の単位は億円に丸めて表記。
     PROMPT

     def generate(security_report)
       facts = build_facts_json(security_report)  # 科目=>金額のJSON（チャートと同じデータ）
       response = client.messages.create(model: MODEL, system: SYSTEM, max_tokens: 400,
         messages: [{ role: "user", content: facts.to_json }])
       ReportCommentary.upsert({ security_report_id: security_report.id,
         body: response.content.first.text, model: MODEL }, unique_by: :security_report_id)
     rescue Anthropic::Error => e
       Sentry.capture_exception(e)  # 生成失敗は握りつぶす: コメントは付加価値であり必須ではない
     end
   end
   ```
3. 日次取込ジョブの末尾で「今回取り込んだ有報」に対して生成（1件ずつ・失敗隔離は取込と同じ方針）
4. GraphQLに `commentary: String` フィールド追加 → フロントで表示（2-5）
5. バックフィルは直近1〜2年分に絞って開始しコスト実測（Haiku級で1件数百トークン・月数ドル規模の想定）
6. 表示側に「AIによる自動要約」のラベルを必ず付ける（誤生成リスクの明示）

### 3-4. 未対応フォーマットのAI支援マッピング

- **意図**: ゼロベース再設計で `unsupported` になる形式（日本基準の保険・証券等）への対応の律速は
  「タグ実測とマッピング表作り」。ここをLLMに下書きさせる

**手順**（ゼロベース再設計実装後・1〜2日）:

1. 取込時に `unsupported` 判定されたら、factダンプ（要素名×コンテキスト×値のTSV）を
   S3等に保存し、`unsupported_format_samples` テーブルに (業種コード, docID, パス) を記録
2. 週次ジョブ: 業種コードごとにサンプル1件のfactダンプをClaude APIに投げる。プロンプト骨子:
   「以下は日本基準・業種コードXXXの有報XBRLのfact一覧。`docs/zero-base-redesign/02` の
   科目コード一覧に対応するタグを、根拠となる値の整合性（合計=内訳の和）と共に提案せよ」
3. 提案をGitHub Issueとして自動起票（gh CLI or API）。**自動でコードに反映しない**——
   マッピングの正しさは人間が実測値と突き合わせて確認し、Extractorクラスとして実装する
4. 実装後、そのサンプルをテストfixture（1-3）に昇格させる

### 3-5. 自然言語での企業スクリーニング

- **意図**: 「営業CFが黒字で投資を続けている会社」→ 検索条件への変換。CF符号フィルタの表現力を拡張

**手順**（ゼロベース再設計の縦持ちスキーマ前提・2〜3日）:

1. backendに変換エンドポイントを追加。Claude APIの**tool use（強制ツール呼び出し）**で
   検索条件スキーマに変換させる:
   ```ruby
   # tools定義 = 検索APIの引数そのもの（operating_cf_sign等）。LLMの出力を自由文でなく
   # スキーマ検証済みのJSONで受けるのが誤変換対策の要
   tool = { name: "search_filter", input_schema: { type: "object", properties: {
     operating_cf_sign: { enum: ["positive", "negative"] },
     investing_cf_sign: { enum: ["positive", "negative"] },
     financing_cf_sign: { enum: ["positive", "negative"] },
   } } }
   ```
2. 変換結果はそのまま既存の `Reports::SearchQuery` に渡す（検索ロジックは共有・新設しない）
3. フロント: 自由入力欄 + 「適用されたフィルタ」をチップ表示（誤変換をユーザーが目視できることが必須）
4. 語彙拡張はスキーマにプロパティを足すだけ（例: `equity_ratio_min`）。
   検索側の実装が縦持ちなら`financial_statement_items`へのEXISTS追加で対応できる

### 3-6. データ品質の異常検知

- **意図**: 「貸借が合わない」「前期比で桁が飛んだ」等の取込異常の早期検知（現在はSentryの例外のみ）

**手順**（backendリポジトリ・1日。まずルールベースで開始、LLMは要約のみ）:

1. 検知ルールをSQL/Rubyで実装（週次rakeタスク）:
   - 貸借乖離: `|資産 - (負債+純資産)| > 資産×10%` の財務諸表
   - 桁飛び: 同一企業の前期比で売上が100倍超 or 1/100未満
   - 欠落: `is_primary` なのに `bs.assets` がない財務諸表（形式判定ミスの兆候）
2. 検知結果が0件なら通知しない。1件以上なら一覧をClaude APIで3行に要約し、
   メール or Slack Webhookで通知（要約が不要なら固定文言でよい—LLMはオプション）
3. 検知された企業のdocIDはそのまま再取込・デバッグの入力になる（`subscribe_by_target_document_ids`）

### 3-7. DB読み取りMCPサーバ（開発補助）

- **意図**: 「IFRS企業で連結が0のままの行は何件?」のような調査をAIエージェントに直接させる

**手順**（ローカル開発環境のみ・1時間）:

1. read-onlyロールを作成:
   ```sql
   CREATE ROLE claude_readonly LOGIN PASSWORD '...';
   GRANT CONNECT ON DATABASE financial_statement TO claude_readonly;
   GRANT USAGE ON SCHEMA public TO claude_readonly;
   GRANT SELECT ON ALL TABLES IN SCHEMA public TO claude_readonly;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO claude_readonly;
   ```
2. 親リポジトリの `.claude/settings.json`（または `.mcp.json`）にPostgreSQL MCPサーバを追加:
   ```json
   { "mcpServers": { "financial-db": {
       "command": "npx", "args": ["-y", "@modelcontextprotocol/server-postgres",
         "postgresql://claude_readonly:...@localhost:5432/financial_statement"] } } }
   ```
   接続文字列はコミットせず環境変数参照にする（1-1と同じ扱い）
3. 動作確認: Claude Codeセッションで「security_reportsの会計基準別件数を出して」と依頼し
   SELECTが飛ぶこと・INSERTが権限エラーになることを確認

---

## 推奨着手順

1. **1-3 テスト基盤 + 1-2 CI**（以後の全変更の安全網。1-1と1-4はこの中で同時に済ませる）
2. **2-1 企業別URL + 2-3 動的sitemap**（SEOの土台。ゼロベース再設計に含めるなら同時に）
3. **3-2 PR自動レビュー**（導入コスト最小のAI活用）
4. **2-2 SSR / 3-3 コメント生成**（サイト価値の本丸。再設計のフロント刷新と同時が効率的）
5. 3-4〜3-7 はゼロベース再設計の実装後に順次
