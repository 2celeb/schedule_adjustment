# Rails テスト環境の設定
require "spec_helper"
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"

# マイグレーションが保留中の場合はテストを中止
begin
  ActiveRecord::Migration.check_all_pending!
rescue ActiveRecord::PendingMigrationError => e
  abort(e.to_s.strip)
end

require "rspec/rails"
require "factory_bot_rails"
# Rantly（プロパティテスト）は必要な時に個別に読み込む
# rantly/rspec_extensions は rspec gem の直接 require に依存するため、
# ここでは読み込まない

# spec/support 配下のファイルを自動読み込み
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # FactoryBot のメソッドを直接使用可能にする
  config.include FactoryBot::Syntax::Methods

  # ActiveSupport のテストヘルパー（travel_to 等）を使用可能にする
  config.include ActiveSupport::Testing::TimeHelpers

  # フィクスチャのパス
  config.fixture_paths = [Rails.root.join("spec/fixtures")]

  # トランザクションを使用してテスト間のデータを分離
  config.use_transactional_fixtures = true

  # コントローラーテストのタイプ推論
  config.infer_spec_type_from_file_location!

  # Rails 固有のバックトレースをフィルタリング
  config.filter_rails_from_backtrace!
end
