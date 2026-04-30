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
  end

  # OAuth エンドポイント（今後のタスクで追加）
  namespace :oauth do
    # タスク 3.4, 3.8 で実装
  end
end
