namespace :graphql do
  desc "GraphQLスキーマをschema.graphqlへ書き出す（スキーマ変更をdiffレビューできるようにする）"
  task dump_schema: :environment do
    File.write("schema.graphql", FinancialStatementSchema.to_definition)
    puts "wrote schema.graphql"
  end
end
