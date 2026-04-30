require_relative "boot"

require "rails"
# API モードに必要なフレームワークのみ読み込み
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"

# Gemfile に記載された gem を読み込み
Bundler.require(*Rails.groups)

module ScheduleAdjustment
  class Application < Rails::Application
    config.load_defaults 7.1

    # API モード
    config.api_only = true

    # Cookie ミドルウェアの追加（セッション管理に必要）
    config.middleware.use ActionDispatch::Cookies

    # タイムゾーン設定
    config.time_zone = "Asia/Tokyo"
    config.active_record.default_timezone = :utc

    # デフォルトロケール
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [:ja, :en]

    # ジェネレーター設定
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.orm :active_record, primary_key_type: :bigint
    end

    # Active Job のバックエンドに Sidekiq を使用
    config.active_job.queue_adapter = :sidekiq

    # autoload パスの設定
    config.autoload_paths += %W[#{config.root}/app/services #{config.root}/app/policies]
  end
end
