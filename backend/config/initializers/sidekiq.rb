# Sidekiq 設定
# Redis 接続とジョブキューの設定

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://redis:6379/0") }

  # sidekiq-cron のスケジュール設定（今後のタスクで追加）
  # config.on(:startup) do
  #   Sidekiq::Cron::Job.load_from_hash(YAML.load_file("config/sidekiq_cron.yml"))
  # end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://redis:6379/0") }
end
