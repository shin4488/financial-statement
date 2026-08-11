# 08. 本番運用

本番環境（https://investee.info ）の構成、デプロイ、日次バッチの監視とリカバリ、
リリースタグの運用。定型作業の詳細手順は `.claude/skills/` の各手順書が正で、
ここでは全体像と考え方をまとめる。

なお、実際の接続先ホスト名・ユーザー名・鍵などは
git管理外のファイル（`deploy.sh` など）だけが持ち、ドキュメントには書かない。

## 本番環境の構成

さくらVPS1台に全コンポーネントが同居する。開発環境（Docker）と違いコンテナは使わず、
OS上に直接構築されている。

```mermaid
flowchart TB
    User["ブラウザ"] -->|https 443| Nginx["nginx<br>TLS終端（Certbot）・セキュリティヘッダ・レート制限"]
    Nginx -->|"/ （静的ファイル）"| Static["Reactビルド成果物<br>（build/ を配置）"]
    Nginx -->|"/api → localhost:30000"| Puma["puma（Rails・production）"]
    Puma --> PG[("PostgreSQL")]
    Sidekiq["Sidekiq（systemd管理）<br>毎日2:00の日次取込"] --> PG
    Sidekiq -.-> Redis[("Redis（専用ポート）")]
    Sidekiq -->|"取込"| EDINET["EDINET API"]
```

開発環境との違いで押さえておくべき点:

| 項目 | 内容 |
|---|---|
| 本番nginxの設定 | **リポジトリ外**（サーバ上の `/etc/nginx/` 直下）にあり、rsyncデプロイの対象外。変更はサーバ上で直接行う |
| フロントエンド | devサーバではなく、ビルド済み静的ファイルをnginxが直接配信する。SPAのフォールバック設定（未知パス→index.html）は本番nginx側の責務 |
| セキュリティヘッダ | nginxで一元管理し、Rails側のヘッダ出力は明示的に止めている（二重出力防止）。CSPはReport-Onlyで運用（AdSenseとMUIがインラインコードを要求するため強制モードにできない） |
| HTTPS | Certbot（Let's Encrypt）による301リダイレクトとTLS終端。Railsの `force_ssl` は使わない（nginxが `X-Forwarded-Proto` を転送しておらず、有効化すると無限リダイレクトになる） |
| レート制限 | `/api/` に対して2リクエスト/秒（バースト20、超過は429）。未認証・公開APIの防御の一部 |

## デプロイ

CI/CDはなく、**ローカルの作業ツリーをrsyncでVPSへ転送して再起動する**方式。
詳細手順とハマりどころは `.claude/skills/deploy/SKILL.md` が正。

```mermaid
flowchart LR
    Check["事前チェック<br>3リポジトリがmain最新・<br>作業ツリーがクリーン"] --> BE["バックエンド転送<br>→ 依存更新・マイグレーション<br>→ puma再起動・起動確認"]
    BE --> FE["フロントエンド<br>ローカルでビルド<br>→ build/ のみ転送"]
    FE --> Verify["反映確認<br>API応答・トップページ200・<br>バンドルハッシュ一致"]
```

運用上の要点:

- **rsyncは未コミットの変更もそのまま本番に載せてしまう**。作業ツリーがクリーンで
  あることの確認が最初の防波堤
- 順序は必ず**バックエンド → フロントエンド**（フロントが新APIに依存し得るため。
  [07章](07_development.md)のマージ順と同じ理屈）
- Sidekiq再起動が必要な変更（ジョブやgemの追加）はsudoを要するため非対話SSHでは
  完結できず、対話端末での操作が必要になる
- 過去に「非対話SSHで再起動スクリプトを実行してAPIが数分停止する」事故があり、
  対話モード強制（`bash -ic`）や `RAILS_ENV=production` の明示など、
  再発防止の決まりが手順書に記録されている

## 日次バッチの監視とリカバリ

[05章](05_backend.md)のとおり自動リトライはなく、**冪等な再実行が唯一のリカバリ手段**。
異常はSentry通知で気づき、対応する再実行コマンドを打つ、が基本形になる。

| Sentry通知（ログメッセージ） | 意味 | リカバリ |
|---|---|---|
| `list failed <日付>`（`EDINET documents.json failed` も同種） | その日の書類一覧の取得自体に失敗（1日分が丸ごと未取込） | **必ず再実行**: `rake 'ingestion:backfill[日付,日付]'` |
| `ingest failed <docID>` | 特定の書類の取込に失敗 | `rake 'ingestion:documents[docID]'` |
| `accounting standard unknown` | 未知の会計基準（取込対象外としてスキップ済み） | 対応不要。頻発するなら形式対応を検討 |
| `primary statement missing bs.assets` | 取り込めたが主要科目が欠けている | Extractor・形式判定を修正して再取込 |

日々の健全性確認は `.claude/skills/investee-daily-check/` のスクリプト1本に
まとまっており、次を一度に確認できる。

- 前夜の日次ジョブがログに痕跡を残しているか、エラー行数はいくつか
- 前日提出分の取込件数と、EDINET側の提出一覧（突き合わせ用）
- 本番サイトの死活（トップページが200を返すか）

読み方の注意として、DBの提出日はEDINETの提出日ではなくXBRL表紙の日付に由来するため、
**訂正有報は元の有報の日付で記録される**。「EDINET一覧に提出があるのに前日日付の
取込件数が0」は、訂正有報のみだった日の正常な結果として読み分ける。

## 監視・ログ

| 仕組み | 内容 |
|---|---|
| Sentry | 例外・警告の通知先。個人情報を送らない設定（EDINET APIキーがURLに含まれるため、リクエスト情報の送出を明示的に抑止している）。パフォーマンストレースは10%サンプリング |
| ログ | lograge形式で `log/production.log` へ。サイズ上限つきローテーション（ディスク枯渇対策）。SQLログは別ファイル |

## リリースタグ

デプロイと連動した自動化はないが、リリースの区切りをGitHub Releaseで記録する。
手順は `.claude/skills/release/SKILL.md` が正。

- タグ名は `release-X.Y.Z`。機能追加ありはYを+1、修正のみはZを+1
- 対象は**親リポジトリは毎回**、backend/frontendは前回タグ以降にコミットがあるものだけ
- 作成順はsubmodule → 親（PRのマージ順と同じ向き）
- リリースノートは公開情報のため、ホスト名・キーなどの実値を書かない

---

用語に迷ったら: [09. 用語集](09_glossary.md)
