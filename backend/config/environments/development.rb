require "active_support/core_ext/integer/time"

Rails.application.configure do
  # 開発環境設定

  # コード変更時にクラスを再読み込み
  config.enable_reloading = true

  # 起動時に全クラスを読み込まない
  config.eager_load = false

  # 詳細なエラーレポートを表示
  config.consider_all_requests_local = true

  # キャッシュ設定
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # Active Record のマイグレーションエラーを表示
  config.active_record.migration_error = :page_load

  # Active Record の詳細ログ
  config.active_record.verbose_query_logs = true

  # ログレベル
  config.log_level = :debug

  # サーバータイミング情報をレスポンスに含める
  config.server_timing = true
end
