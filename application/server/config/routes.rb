Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  get "sandbox/" => "sandbox/sandbox#index"
  get "sandbox2/" => "sandbox/sandbox2#index"
end
