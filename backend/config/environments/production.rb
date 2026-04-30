require "active_support/core_ext/integer/time"

Rails.application.configure do
  # 本番環境設定

  # 全クラスを事前読み込み
  config.enable_reloading = false
  config.eager_load = true

  # ローカルリクエストとして扱わない
  config.consider_all_requests_local = false

  # キャッシュ有効化
  config.action_controller.perform_caching = true

  # 静的ファイルの配信（Nginx が担当するため無効化）
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # ログレベル
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym

  # ログフォーマッタ
  config.log_tags = [:request_id]

  # Active Record のダンプ形式
  config.active_record.dump_schema_after_migration = false

  # SSL を強制
  config.force_ssl = true
end
