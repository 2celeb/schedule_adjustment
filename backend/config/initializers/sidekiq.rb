# Sidekiq 設定
# Redis 接続とジョブキューの設定

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://redis:6379/0") }

  # sidekiq-cron のスケジュール設定
  config.on(:startup) do
    schedule_file = Rails.root.join("config", "sidekiq_cron.yml")
    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file))
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://redis:6379/0") }
end
