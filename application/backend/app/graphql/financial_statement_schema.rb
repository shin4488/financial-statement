class FinancialStatementSchema < GraphQL::Schema
  query(Types::QueryType)

  use GraphQL::Dataloader

  # 公開・未認証エンドポイントのため、1リクエストで実行できる総量を制限する
  # （エイリアス大量並記による増幅DoS対策）。
  # 上限は実クエリとgraphql-codegenのイントロスペクションが余裕をもって収まる値にする。
  # depthはイントロスペクションが最も深く、codegenのバージョン差で失敗しないよう緩めに取る
  # （スキーマに再帰型がなく、実クエリの深さはスキーマ構造で頭打ちになるため、
  # depthを緩めても増幅の余地は増えない）
  max_complexity 400
  max_depth 20

  validate_max_errors(100)
end
