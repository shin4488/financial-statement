# investee の利用状況と改善判断

GA4 Web プロパティ: `407300014`（測定 ID `G-ZCJ8NTQ6KY`）。
拡張機能は別プロパティ `463560127`。両者のユーザー数を足しても実人数にはならない。

## 週に一度見る順序

同じ長さの期間（まず過去28日とその前の28日）で比較する。少数の利用では率が大きく動くため、必ずユーザー数・イベント数を併記する。

| 確認すること | 見るもの | 次に調べる改善候補 |
| --- | --- | --- |
| 利用されているか | アクティブユーザー、新規・リピーター、流入元 | 流入減なら検索流入・拡張からの導線、再訪減なら更新頻度・使い勝手 |
| 目的の企業へ到達できるか | search_submit と report_result、検索方法別の表示結果 | empty が多ければ対象企業・入力案内・データ収録、error が多ければAPIの稼働状況 |
| 分析に使われているか | analysis_interaction のユーザー数、グラフの種類 | 表示成功に対して操作が少なければグラフの説明・ナビゲーション・初期表示 |
| どこで止まるか | report_load_more の結果、デバイス別のキーイベント率 | 追加読込失敗やスマートフォンだけの低下を再現して確認 |
| 外部へ調査を続けているか | outbound_click | 企業名リンクの認知・関連情報への導線 |

これらは原因の断定ではなく調査の入口。イベント数の単純な割算を、同じ利用者が順番に進んだファネル率として扱わない。経路はGA4のファネル探索で同一セッション・順序を指定する。

## 計測の契約

| イベント | 発火条件 | 主なパラメータ |
| --- | --- | --- |
| page_view | 初回とページ分類の変更。検索クエリ変更・StrictMode再実行では増やさない | 正規化したpage_location / page_title |
| search_submit | 利用者が検索条件を変更した時 | search_mode、stock_count |
| report_result | 検索結果が確定した時。追加読込では増やさない | result_status、result_count、unavailable_count、search_mode |
| report_load_more | 追加読込が完了・失敗した時 | result_status、result_count |
| analysis_interaction | 手動グラフ切替、自動切替設定の変更 | interaction_type、chart_type |
| outbound_click | 企業名から株探へ移動 | link_domain |

`result_status`: success / empty / error。
`search_mode`: browse / stock / cash_flow / combined。
`chart_type`: bs / pl / cf / indicators。
`unavailable_count` は「3表のうち1つ以上が表示不可のレポート数」であり、通信失敗数ではない。
`analytics_version=2` は新しい計測契約。過去のclickや旧イベントと直接増減比較しない。

キーイベントは `analysis_interaction`（セッションごとに1回、金額なし）。自動再生や単なる表示を成果として数えない。
カスタム定義はイベントスコープで「表示結果=result_status」「検索方法=search_mode」「分析操作=interaction_type」「グラフの種類=chart_type」。数値パラメータを集計する場合はGA4のカスタム指標に登録する。

本番ビルドかつ `investee.info` のみ送信。ローカル・previewは本番データを汚さない。
自由入力・検索内容・証券コード・query/hashは送らない。GA4の拡張計測は手動page_viewや独自クリックとの重複を避ける設定にする。

<a id="sequence-analytics"></a>

## 計測の流れ

[財務データの表示](../guide/03_data_flow.md#sequence-display)や利用者の操作をきっかけに送信する。計測の失敗で財務表示を止めない。Webと拡張では送信経路・集計先が異なる。

### Web：ブラウザから送信

```mermaid
sequenceDiagram
    participant P as Web画面
    participant A as 計測処理
    participant G as Web用GA4
    P->>A: 検索結果の確定・手動操作など
    A->>A: 本番環境か確認し、許可した項目だけ作る
    opt 計測が有効
        A->>G: SDKでイベントを送信
    end
    Note over P,G: 検索内容・証券コード・URLのquery/hashは送らない
```

### 拡張機能：サーバで検証して中継

```mermaid
sequenceDiagram
    participant P as 拡張ポップアップ
    participant A as investeeの計測API
    participant G as 拡張用GA4
    P->>A: 許可されたイベントと識別子を送信
    A->>A: 本文サイズ・イベント・値を検証
    alt 入力が不正
        A-->>P: 400 / 413 / 415
    else 入力が有効
        A->>A: 識別子を変換し、サーバの送信設定を使う
        alt 送信設定がない
            A-->>P: 503
        else 送信設定がある
            A->>G: 固定の送信先へ転送
            alt 正常応答
                G-->>A: 受信
                A-->>P: 204
            else 通信失敗・異常応答
                A-->>P: 503（自動再試行なし）
            end
        end
    end
    Note over P,G: 204は集計完了の保証ではない
```

## 拡張機能の設定と計測の確認

拡張は `POST /api/analytics/extension` を使う。公開前に中継APIをデプロイし、Git管理外のbackend `config/application.yml` に次を設定する。

| 項目 | 設定する値 |
|---|---|
| `EXTENSION_GA_MEASUREMENT_ID` | 拡張用データストリームの測定ID |
| `EXTENSION_GA_API_SECRET` | 同ストリームのMeasurement Protocol API secret。ブラウザ用変数や配布物には含めない |

公開後は手動操作し、GA4リアルタイムでイベントとパラメータを確認する。拡張のHTTP 204は集計成功を保証しないため、送信内容の検証にはMeasurement Protocolのdebugエンドポイントを使う（検証リクエスト自体は集計されない）。

通常レポートや新しいカスタム定義の反映には24〜48時間かかる場合があり、過去分も補完されない。公開直後の0件だけで障害と判断しない。

拡張はWeb SDKと計測方法が異なる。地域・端末・流入・新規／再訪をWebと同じ精度で解釈せず、サイト名・表示結果・操作・バージョンと総ユーザー数を中心に見る。

公式仕様: [Measurement Protocol](https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference)、[イベントの検証](https://developers.google.com/analytics/devguides/collection/protocol/ga4/validating-events)。
