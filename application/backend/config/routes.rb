Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"
  post "/analytics/extension", to: "analytics#create"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "graphql#execute"
  end
end
