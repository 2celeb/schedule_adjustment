# Rails テスト環境の設定
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# マイグレーションが保留中の場合はテストを中止
abort("テストデータベースのマイグレーションが保留中です。bin/rails db:migrate RAILS_ENV=test を実行してください。") if Rails.env.test? && ActiveRecord::Base.connection rescue nil

require "rspec/rails"
require "factory_bot_rails"
require "rantly"
require "rantly/rspec_extensions"

# spec/support 配下のファイルを自動読み込み
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # FactoryBot のメソッドを直接使用可能にする
  config.include FactoryBot::Syntax::Methods

  # フィクスチャのパス
  config.fixture_paths = [Rails.root.join("spec/fixtures")]

  # トランザクションを使用してテスト間のデータを分離
  config.use_transactional_fixtures = true

  # コントローラーテストのタイプ推論
  config.infer_spec_type_from_file_location!

  # Rails 固有のバックトレースをフィルタリング
  config.filter_rails_from_backtrace!
end
