class FinancialStatementSchema < GraphQL::Schema
  query(Types::QueryType)

  # For batch-loading (see https://graphql-ruby.org/dataloader/overview.html)
  use GraphQL::Dataloader

  # 公開・未認証エンドポイントのため、1リクエストで実行できる総量を制限する
  # （エイリアス大量並記による増幅DoS対策）。
  # 通常の一覧クエリは複雑度40前後、graphql-codegenのイントロスペクションは200前後。
  # depthは、実クエリが5に対しイントロスペクションが13と最も深い。codegenの
  # バージョン差で失敗しないよう余裕を取る（スキーマに再帰型がなく、実クエリの深さは
  # スキーマ構造で頭打ちになるため、depthを緩めても増幅の余地は増えない）
  max_complexity 400
  max_depth 20

  # GraphQL-Ruby calls this when something goes wrong while running a query:
  def self.type_error(err, context)
    # if err.is_a?(GraphQL::InvalidNullError)
    #   # report to your bug tracker here
    #   return nil
    # end
    super
  end

  # Union and Interface Resolution
  def self.resolve_type(abstract_type, obj, ctx)
    # TODO: Implement this method
    # to return the correct GraphQL object type for `obj`
    raise(GraphQL::RequiredImplementationMissingError)
  end

  # Stop validating when it encounters this many errors:
  validate_max_errors(100)

  # Relay-style Object Identification:

  # Return a string UUID for `object`
  def self.id_from_object(object, type_definition, query_ctx)
    # For example, use Rails' GlobalID library (https://github.com/rails/globalid):
    object.to_gid_param
  end

  # Given a string UUID, find the object
  def self.object_from_id(global_id, query_ctx)
    # For example, use Rails' GlobalID library (https://github.com/rails/globalid):
    GlobalID.find(global_id)
  end
end
