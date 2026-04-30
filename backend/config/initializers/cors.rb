# CORS（Cross-Origin Resource Sharing）設定
# フロントエンドドメインのみからのリクエストを許可する
# 環境変数 CORS_ORIGINS でカンマ区切りで許可するオリジンを指定可能

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # CORS_ORIGINS 環境変数からオリジンを取得（カンマ区切り）
    # 未設定の場合は開発環境のデフォルト値を使用
    allowed_origins = ENV.fetch("CORS_ORIGINS", "http://localhost:5173,http://localhost").split(",").map(&:strip)
    origins(*allowed_origins)

    resource "*",
      headers: %w[Content-Type Authorization X-User-Id],
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,        # Cookie 送信を許可
      max_age: 3600             # プリフライトリクエストのキャッシュ（1時間）
  end
end
