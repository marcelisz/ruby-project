Rails.application.routes.draw do
  root "home#index"

  devise_for :users, only: :omniauth_callbacks,
                     controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  as :user do
    get "login", to: "users/sessions#new", as: :new_user_session
    delete "logout", to: "users/sessions#destroy", as: :destroy_user_session
  end

  get "search", to: "search#index", as: :search
  resources :tags, only: :show
  resources :users, only: :show
  get "autocomplete/tags", to: "autocomplete#tags", as: :tags_autocomplete

  patch "preferences/language", to: "preferences#language", as: :language_preference
  patch "preferences/theme", to: "preferences#theme", as: :theme_preference

  get "admin", to: "admin/users#index", as: :admin
  namespace :admin do
    resources :users, only: %i[index destroy] do
      member do
        patch :block
        patch :unblock
        patch :toggle_admin
      end
    end
  end

  resources :inventories do
    resources :items, only: %i[new create show update] do
      collection { delete :bulk_destroy }
      resource :like, only: :create, controller: "likes"
    end
    resources :fields, only: :index, controller: "inventory_fields" do
      collection { patch :update_all }
    end

    member do
      get :stats
      get :export
      get "export/csv", to: "inventories#export_csv", as: :export_csv
      get "export/xlsx", to: "inventories#export_xlsx", as: :export_xlsx
      get :custom_id, to: "custom_ids#show", as: :custom_id
      patch :custom_id, to: "custom_ids#update"
      get :access, to: "inventory_accesses#index", as: :access
      patch :access, to: "inventory_accesses#update"
      post :access, to: "inventory_accesses#create"
      delete "access/:user_id", to: "inventory_accesses#destroy", as: :remove_access
      get :user_autocomplete, to: "autocomplete#users"
      get :chat, to: "messages#index", as: :chat
      post :chat, to: "messages#create"
      get "chat/feed", to: "messages#feed", as: :chat_feed
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
