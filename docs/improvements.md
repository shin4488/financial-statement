# 改善バックログ — DX / SEO・Web / AI活用

未着手の改善候補を「現状・意図 → 作業手順」の形で、着手時にそのまま手を動かせる粒度で書く。
対応が完了した項目は記述ごと削除する（完了の記録はgit履歴とdocs/guide/が持つ）。

前提知識: このリポジトリは単一リポジトリ（monorepo）。CIは `.github/workflows/` の
backend-ci / frontend-ci が `paths:` フィルタで変更のあった側だけ実行される（詳細は [CLAUDE.md](../CLAUDE.md)）。

---

## 2. SEO・Webサイト品質

### 2-1. 企業別URLの導入【SEO効果が最も大きい】

- **現状**: 画面が `/` の1URL（検索条件はURLクエリに乗る）。Googleから見ると「1ページのサイト」で、
  「〇〇(企業名) 財務諸表」等の個別クエリの受け皿がない
- **意図**: 上場企業約4,000社 × 会計年度分のロングテール検索流入の土台

**手順**（frontend中心・2〜3日）:

1. ルート定義（`App.tsx`）:
   ```tsx
   <Routes>
     <Route path="/companies/:stockCode" element={<CompanyPage />} />
     <Route path="*" element={<FinancialReportListPage />} />
   </Routes>
   ```
2. `CompanyPage` は一覧の実装を流用: `useParams()` の stockCode を `financialReports` クエリの
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
6. SPAの直リンク対応: 本番nginxの `try_files $uri /index.html;` は確認済み。
   開発の `web/` はdevサーバproxyのため対応不要

### 2-2. プリレンダリング / SSR

- **現状**: CRAのCSR。クローラの初期HTMLは空の `<div id="root">`。SNSカードも全URL共通
- **意図**: 2-1の企業ページを確実・高速にインデックスさせ、企業ごとのOGPを出す

**手順**（Next.js移行案・1〜2週間）:

1. `npx create-next-app`（App Router・TypeScript）で新規プロジェクトを application/frontend の
   `next/` に作成（並行稼働のため既存 `src/` は残す）
2. 移植マッピング:
   | 現行 | Next.js |
   |---|---|
   | `public/index.html` のmeta群 | `app/layout.tsx` の `metadata` |
   | `features/financialReports` | `app/page.tsx`（一覧・CSRのままでよい） |
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

- **現状**: 静的sitemap.xml（トップのみ）
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
       companies = Disclosure::Company.joins(:reports)
                          .group(:id).select("companies.*, MAX(reports.filing_date) AS last_filed")
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

**手順**（frontend・1日）:

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
  （`commentary` フィールドをGraphQLに追加）。コメント未生成の企業は非表示にするだけ。
  ページ下部に「データ出典: EDINET（金融庁）」の明記も追加（E-E-A-T対策・半日）

---

## 3. AI活用

（PR自動レビューは不採用: レビューはローカルのClaude Codeで実施できるため、
CI常設のAPIコスト・Secrets管理に見合わない）

### 3-3. 財務コメントの自動生成（SEOコンテンツ兼用）

- **意図**: 可視化に「読み」を添えて価値を上げ、2-5のテキスト不足も解消

**手順**（backend・2〜3日）:

1. テーブル追加:
   ```ruby
   create_table :report_commentaries, comment: "有報サマリコメント（AI生成）" do |t|
     t.references :report, null: false, index: { unique: true }
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

     def generate(report)
       facts = build_facts_json(report)  # 科目=>金額のJSON（チャートと同じデータ）
       response = client.messages.create(model: MODEL, system: SYSTEM, max_tokens: 400,
         messages: [{ role: "user", content: facts.to_json }])
       ReportCommentary.upsert({ report_id: report.id,
         body: response.content.first.text, model: MODEL }, unique_by: :report_id)
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

- **意図**: `unsupported` 判定になる形式（日本基準の保険・証券等）への対応の律速は
  「タグ実測とマッピング表作り」。ここをLLMに下書きさせる

**手順**（1〜2日）:

1. 取込時に `unsupported` 判定されたら、factダンプ（要素名×コンテキスト×値のTSV）を
   S3等に保存し、`unsupported_format_samples` テーブルに (業種コード, docID, パス) を記録
2. 週次ジョブ: 業種コードごとにサンプル1件のfactダンプをClaude APIに投げる。プロンプト骨子:
   「以下は日本基準・業種コードXXXの有報XBRLのfact一覧。`docs/guide/03_system_overview.md` の
   科目コード一覧に対応するタグを、根拠となる値の整合性（合計=内訳の和）と共に提案せよ」
3. 提案をGitHub Issueとして自動起票（gh CLI or API）。**自動でコードに反映しない**——
   マッピングの正しさは人間が実測値と突き合わせて確認し、Extractorクラスとして実装する
4. 実装後、そのサンプルをテストfixture（spec/fixtures/xbrl）に昇格させる

### 3-5. 自然言語での企業スクリーニング

- **意図**: 「営業CFが黒字で投資を続けている会社」→ 検索条件への変換。CF符号フィルタの表現力を拡張

**手順**（2〜3日）:

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
2. 変換結果はそのまま`Disclosure::SearchQuery` に渡す（検索ロジックは共有・新設しない）
3. フロント: 自由入力欄 + 「適用されたフィルタ」をチップ表示（誤変換をユーザーが目視できることが必須）
4. 語彙拡張はスキーマにプロパティを足すだけ（例: `equity_ratio_min`）。
   検索側の実装が縦持ちなら`financial_statement_items`へのEXISTS追加で対応できる

### 3-6. データ品質の異常検知

- **意図**: 「貸借が合わない」「前期比で桁が飛んだ」等の取込異常の早期検知
  （現在は取込時の例外と「is_primaryなのにbs.assetsがない」のSentry警告のみ）

**手順**（backend・1日。まずルールベースで開始、LLMは要約のみ）:

1. 検知ルールをSQL/Rubyで実装（週次rakeタスク）:
   - 貸借乖離: `|資産 - (負債+純資産)| > 資産×10%` の財務諸表
   - 桁飛び: 同一企業の前期比で売上が100倍超 or 1/100未満
2. 検知結果が0件なら通知しない。1件以上なら一覧をClaude APIで3行に要約し、
   メール or Slack Webhookで通知（要約が不要なら固定文言でよい—LLMはオプション）
3. 検知された企業のdocIDはそのまま再取込・デバッグの入力になる（`rake ingestion:documents`）

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
2. リポジトリの `.claude/settings.json`（または `.mcp.json`）にPostgreSQL MCPサーバを追加:
   ```json
   { "mcpServers": { "financial-db": {
       "command": "npx", "args": ["-y", "@modelcontextprotocol/server-postgres",
         "postgresql://claude_readonly:...@localhost:5432/financial_statement"] } } }
   ```
   接続文字列はコミットせず環境変数参照にする（git管理ファイルに実値を書かない運用ルールに従う）
3. 動作確認: Claude Codeセッションで「reportsの会計基準別件数を出して」と依頼し
   SELECTが飛ぶこと・INSERTが権限エラーになることを確認

---

## 推奨着手順

1. **2-1 企業別URL + 2-3 動的sitemap**（SEOの土台）
2. **2-2 SSR / 3-3 コメント生成**（サイト価値の本丸）
3. 3-4〜3-7 は順次
