# RSpec 基本設定
RSpec.configure do |config|
  # 期待値の構文設定
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # モックの設定
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # 共有コンテキストのメタデータ自動適用
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # テスト実行順序をランダム化
  config.order = :random
  Kernel.srand config.seed
end
