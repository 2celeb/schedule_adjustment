require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # ヘルスチェック
  get "up", to: proc { [200, {}, ["OK"]] }

  # Sidekiq 管理画面（開発環境のみ）
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end

  # API エンドポイント
  namespace :api do
    # セッション管理
    resource :sessions, only: [:destroy]

    # Google 連携解除（タスク 3.6）
    # 表示名変更（タスク 5.2）
    resources :users, only: [] do
      resource :google_link, only: [:destroy]
      resource :display_name, only: [:update]
    end

    # メンバー管理（タスク 5.2）
    resources :memberships, only: [:update]

    # グループ関連（タスク 5.1）
    # show は share_token でアクセス（認証不要）
    resources :groups, only: [:show], param: :share_token do
      # メンバー一覧取得（タスク 5.2）
      resources :members, only: [:index], controller: "memberships"

      # 参加可否（タスク 6.1）
      # GET: 全メンバーの参加可否取得（認証不要）
      # PUT: 参加可否の一括更新（ゆるい識別 or Cookie）
      resource :availabilities, only: [:show, :update]

      # カレンダー同期（タスク 16.6）
      # POST: 強制同期（今すぐ同期）— キャッシュを無視して FreeBusy を再取得
      resource :calendar_sync, only: [:create]
    end

    # update, regenerate_token は id でアクセス（Owner のみ、Cookie 認証）
    resources :groups, only: [:update] do
      member do
        post :regenerate_token
      end

      # 活動日管理（タスク 13.1）
      resources :event_days, only: [:index, :create]

      # 自動確定ルール（タスク 13.3）
      resource :auto_schedule_rule, only: [:show, :update]
    end

    # 活動日の更新・削除（タスク 13.1）
    resources :event_days, only: [:update, :destroy]

    # 内部 API（Discord Bot → Rails）（タスク 5.3）
    namespace :internal do
      resources :groups, only: [:create] do
        member do
          post :sync_members
          get :weekly_status
        end
      end

      # 通知トリガー（タスク 14.1, 14.2）
      namespace :notifications do
        post :remind
        post :daily
      end
    end
  end

  # OAuth エンドポイント
  namespace :oauth do
    # Google OAuth（タスク 3.4）
    get "google", to: "google#authorize"
    get "google/callback", to: "google#callback"

    # Discord OAuth（タスク 3.8）
    get "discord", to: "discord#authorize"
    get "discord/callback", to: "discord#callback"
  end
end
