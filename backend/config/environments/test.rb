require "active_support/core_ext/integer/time"

Rails.application.configure do
  # テスト環境設定

  # テスト時は全クラスを事前読み込み
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?

  # テスト環境はローカルリクエストとして扱う
  config.consider_all_requests_local = true

  # キャッシュ無効化
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # 例外を発生させる（テストで検出しやすくする）
  config.action_controller.allow_forgery_protection = false

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecations = :raise

  # ログレベル
  config.log_level = :warn
end
