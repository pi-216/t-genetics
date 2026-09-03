Rails.application.routes.draw do
  # Identity context — org sign-up (PRD-0002. Sign-up creates an organization
  # with the user as its owner and signs them in.

  get "register" => "identity/registrations#new"
  post "register" => "identity/registrations#create"

  get "login" => "identity/sessions#new"
  post "login" => "identity/sessions#create"
  post "logout" => "identity/sessions#destroy"

  if Rails.env.development? || Rails.env.test?
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end

  resources :chromosomes do
    resources :alleles, module: :chromosomes, except: %i[new edit]

    resources :generations do
      member do
        post 'procreate'
      end
      resources :organisms
    end
  end

  root 'chromosomes#index'
end
