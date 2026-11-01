Rails.application.routes.draw do
  resources :users, only: [:index, :show]
  resources :posts, only: [:index, :show] do
    member do
      get 'renderer'
    end
  end

  namespace :api do
    resources :posts, only: :show
  end
end
