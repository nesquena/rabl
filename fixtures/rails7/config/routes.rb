Rails.application.routes.draw do
  resources :users
  resources :posts do
    member do
      get 'renderer'
    end
  end
end
