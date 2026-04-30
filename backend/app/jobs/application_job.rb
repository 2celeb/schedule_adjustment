# アプリケーション全体の基底ジョブ
class ApplicationJob < ActiveJob::Base
  # リトライ設定（デフォルト: 最大3回）
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
end
