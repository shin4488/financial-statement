require "rails_helper"

# 未認証で公開する /graphql が、上限を超える入力に返すエラーの応答
RSpec.describe "GraphQLの上限を超える入力", type: :request do
  let(:query) do
    "query($limit: Int!, $offset: Int!, $codes: [String!]) " \
      "{ financialReports(limit: $limit, offset: $offset, stockCodes: $codes) { stockCode } }"
  end
  let(:codes) { (1000..1100).map(&:to_s) }

  before { host! ENV.fetch("SERVER_HOST_NAME", "www.example.com") }

  def post_graphql(query, variables = {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  def argument_error(message)
    { "data" => nil,
      "errors" => [ { "message" => message, "locations" => [ { "line" => 1, "column" => 57 } ], "path" => [ "financialReports" ] } ] }
  end

  it "limit・offset・stockCodesが範囲外なら、引数の検証の文言でエラーを返す" do
    {
      { "limit" => 0, "offset" => 0 } => "limit must be greater than 0",
      { "limit" => 101, "offset" => 0 } => "limit must be less than or equal to 100",
      { "limit" => 1, "offset" => -1 } => "offset must be greater than or equal to 0",
      { "limit" => 1, "offset" => 0, "codes" => codes } => "stockCodes is too long (maximum is 100)"
    }.each do |variables, message|
      expect(post_graphql(query, variables)).to eq argument_error(message)
    end
  end

  it "limit 1・100、stockCodes 100件は範囲内として実行する" do
    [ { "limit" => 1, "offset" => 0 }, { "limit" => 100, "offset" => 0, "codes" => codes.first(100) } ].each do |variables|
      expect(post_graphql(query, variables)).to eq("data" => { "financialReports" => [] })
    end
  end

  it "複雑度が400を超えると、実行せずにエラーを返す" do
    # 一覧1つの複雑度は「子の複雑度 + limit / 2」で、{ stockCode } だけなら 1 + limit / 2
    query_with = lambda do |last_limit|
      lists = (1..7).map { |n| "a#{n}: financialReports(limit: 100, offset: 0) { stockCode }" }
      "{ #{lists.join(' ')} a8: financialReports(limit: #{last_limit}, offset: 0) { stockCode } }"
    end

    expect(post_graphql(query_with.call(84))).to eq("data" => (1..8).to_h { |n| [ "a#{n}", [] ] })
    expect(post_graphql(query_with.call(86)))
      .to eq("errors" => [ { "message" => "Query has complexity of 401, which exceeds max complexity of 400" } ])
  end

  it "深さが20を超えると、実行せずにエラーを返す" do
    # イントロスペクションも深さに数える。ofType を n 段重ねると深さは n + 5
    query_with = ->(nesting) { "{ __schema { types { fields { type { #{'ofType { ' * nesting}name#{' }' * nesting} } } } } }" }

    expect(post_graphql(query_with.call(15))["errors"]).to be_nil
    expect(post_graphql(query_with.call(16)))
      .to eq("errors" => [ { "message" => "Query has depth of 21, which exceeds max depth of 20" } ])
  end
end
