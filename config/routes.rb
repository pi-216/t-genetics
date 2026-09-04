Rails.application.routes.draw do
  # Identity context — org sign-up (PRD-0002. Sign-up creates an organization
  # with the user as its owner and signs them in.

  get "register" => "identity/registrations#new"
  post "register" => "identity/registrations#create"

  get "join" => "identity/invitations#new"
  post "join" => "identity/invitations#create"

  get "login" => "identity/sessions#new"
  post "login" => "identity/sessions#create"
  post "logout" => "identity/sessions#destroy"

  get "organization/invite_code" => "identity/invite_codes#show", as: :organization_invite_code
  post "organization/invite_code" => "identity/invite_codes#create"

  # Org settings surface — member-management and token-management sections
  # render owner-only (PRD-0002 DEV-0008 / issue #18).
  get "settings" => "identity/settings#show", as: :settings

  # Owner-only API-token creation (PRD-0005 DEV-0001 / issue #36). The form
  # lives on the settings page; the plaintext is shown once in the flash.
  post "organization/api_tokens" => "identity/api_tokens#create", as: :api_tokens

  # Machine API (PRD-0005) — every endpoint authenticates via a Bearer token
  # scoped to an organization; see Api::V1::BaseController.
  namespace :api do
    namespace :v1 do
      resources :chromosomes, only: %i[index create]
      resources :experiments, only: %i[index create] do
        member do
          post :suggestion
        end
      end
      resources :performance_logs, only: [] do
        member do
          post :outcome
        end
      end
    end
  end

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

  # Web experiment workspace (PRD-0003) — org-scoped experiment index, creation
  # form, detail page, and the loop's request-suggestion action. Creation runs
  # Experiments::Setup (name + chromosome + population size); the suggestion
  # action runs Experiments::RequestSuggestion; the machine API lives under
  # /api/v1/experiments.
  resources :experiments, only: %i[index new create show] do
    member do
      post :suggestion
      post :report
    end
  end

  # Public landing page (PRD-0001) — the product's front door. The workspace
  # stays reachable at /chromosomes via the resources routes below.
  root 'landing#show'
end
