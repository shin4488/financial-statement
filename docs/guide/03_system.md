# 03. システムの構成と実装

この章は、システムの構成、日次取込、公開API、画面の状態管理を説明する。

## 構成

画面はReact、データの取得と配信はRailsが担当する。

| 部品 | 役割 |
|---|---|
| SPA（Single Page Application） | 画面担当。最初にHTMLとJavaScriptを読み込んだ後は、ページ遷移せずJavaScriptが画面を書き換える方式。investeeの画面はReactで作られたSPA |
| APIサーバ | データ担当。画面を持たず、データだけを返すサーバ（Rails）。フロントエンドからネットワーク越しに呼び出される |
| バッチ処理 | 取込担当。ユーザーの操作とは無関係に、決まった時刻に走る処理。EDINETからのデータ取込がこれにあたる |

### 開発環境の構成

```mermaid
flowchart LR
    Browser["ブラウザ<br>localhost:10000"] --> Web
    subgraph "Docker Compose"
        Web["web（nginx）"] -->|"/ へのアクセス"| Front["appfront（Vite devサーバ）"]
        Web -->|"/api へのアクセス"| Server["appserver（Rails + Sidekiq）"]
        Server --> Database[("database<br>PostgreSQL")]
        Server -->|"スケジュール"| Cache[("cache<br>Redis")]
    end
    Browser2["動作確認用<br>localhost:20000"] --> Server
```

Redisは取込ジョブのスケジュールを保持する。財務データのキャッシュには使わない。

## 取込ジョブの信頼性

Sidekiqが毎日2:00に前日提出分を取り込む。手動で日付範囲を指定するときも同じ処理を使う。EDINETへのリクエスト集中を避けるため、書類は間隔を空けて1件ずつ処理する（docIDを指定するrakeのタスクも同じ）。

<a id="sequence-daily"></a>

```mermaid
sequenceDiagram
    participant J as Sidekiq / 日次ジョブ
    participant F as IngestFilings
    participant E as EDINET API
    participant R as SequentialRunner
    participant I as IngestReport
    participant M as ログ / Sentry
    J->>F: 前日提出分の取込を開始
    F->>E: 日付ごとの書類一覧を取得
    alt 一覧を取得できない
        F->>M: 日付と失敗を記録
        Note over F: この日は未取込。対象期間の次の日へ進む
    else 一覧を取得できた
        F->>R: 書類一覧と、1件の取込・記録の仕方・待ち方を渡す
        loop 対象書類を1件ずつ（失敗した書類の後も間隔を空ける）
            R->>I: 書類IDと一覧の証券コードで取込を呼ぶ
            Note over I: 原本取得・対象確認 → 科目抽出・保存
            alt 例外が発生
                I-->>R: 失敗
                R->>M: 書類IDと失敗を記録
            else 例外なし
                I-->>R: 保存、または対象外・数値なしで終了
                R->>M: 処理の終了を記録
            end
        end
    end
    F-->>J: 終了（失敗分の自動再試行はしない）
```

処理終了のログだけでは、科目が更新されたとは限らない。

## 公開APIとしての防御

`/graphql` はログイン不要で利用できるため、1回の問い合わせで取得できる量と処理の複雑さを制限する。

| 設計 | 内容・理由 |
|---|---|
| 入力量の上限 | `limit` 1〜100、`stockCodes` 最大100件、クエリ複雑度400・深さ20まで |
| 件数に応じた負荷の評価 | 取得件数が多い問い合わせほど、複雑度を高く評価する |

## 一覧画面の実装

<a id="sequence-search"></a>

```mermaid
sequenceDiagram
    actor U as 利用者
    participant P as 一覧画面 / URL
    participant C as Apollo Client
    participant A as GraphQL
    U->>P: 証券コード・CF条件を変更
    P->>P: URLへ反映し、検索条件を読み取る
    P->>C: 検索条件と先頭からの取得を指定
    C->>A: financialReports
    Note over A: DB検索・チャートと指標の組み立て
    A-->>C: カードのデータ
    C-->>P: 条件ごとの結果を保持して表示
    opt 一覧の続きが必要
        U->>P: 末尾近くへスクロール
        P->>C: 同じ条件で次の取得位置を指定
        C->>A: financialReports
        A-->>C: 続きのデータ
        C-->>P: 取得位置に合わせて一覧へ追加
    end
```

### 状態と取得結果の管理

| 対象 | 管理方法 |
|---|---|
| 検索条件 | URLの入力を整えてから検索に使い、不明な条件や件数の上限を処理する |
| 追加読込 | 取得件数が要求した件数より少なければ終了する |
| 自動切替 | localStorageに保存する。保存済みの設定がなければON |

APIの接続先は相対パス`/api/graphql`。nginxがRailsへ中継するため、Web側の接続先は開発・本番で共通になる。

## 静的ページ・SEO・計測

| 項目 | 現状 |
|---|---|
| ページ情報（検索結果・SNS向け） | `index.html` に一覧ページの値を書く。静的ページの表示中だけ `usePageMeta` が title・description・canonical を差し替える。OGP・JSON-LDは差し替えない |
| 公開ファイル | `robots.txt` はクロールを許可。`sitemap.xml` はトップと案内4ページを掲載。`ads.txt` は広告の販売者情報 |
| 広告 | Google AdSenseのスクリプトを読み込み |
| 利用状況の計測 | [計測ガイド](../analytics/README.md) |
