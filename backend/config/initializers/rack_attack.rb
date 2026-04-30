# rack-attack によるレート制限設定
# API エンドポイントへの過剰なリクエストを制限する
# テスト環境ではレート制限を無効化する

class Rack::Attack
  # キャッシュストアに Rails のキャッシュを使用
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # テスト環境ではレート制限を無効化
  unless Rails.env.test?
    # 基本レート制限: 1分あたり60リクエスト/IP
    throttle("api/ip", limit: 60, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/api")
    end

    # 認証エンドポイントへの厳しいレート制限: 1分あたり10リクエスト/IP
    throttle("auth/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/oauth")
    end
  end

  # レート制限超過時のレスポンス
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: { code: "RATE_LIMIT_EXCEEDED", message: "リクエスト数が制限を超えました。しばらく待ってから再試行してください。" } }.to_json]
    ]
  end
end
