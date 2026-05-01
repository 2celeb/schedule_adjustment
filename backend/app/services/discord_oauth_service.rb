# frozen_string_literal: true

# Discord OAuth 2.0 認証サービス
# 認証コード取得 → トークン交換 → ユーザー情報取得のフローを管理する
# Owner の Discord アカウント確認に使用
class DiscordOauthService
  TOKEN_ENDPOINT = "https://discord.com/api/v10/oauth2/token"
  USERINFO_ENDPOINT = "https://discord.com/api/v10/users/@me"
  AUTHORIZE_ENDPOINT = "https://discord.com/oauth2/authorize"

  # スコープ: ユーザー情報の読み取り
  SCOPE = "identify"

  class Error < StandardError; end
  class TokenExchangeError < Error; end
  class UserInfoError < Error; end

  def initialize
    @client_id = ENV.fetch("DISCORD_CLIENT_ID")
    @client_secret = ENV.fetch("DISCORD_CLIENT_SECRET")
  end

  # Discord OAuth 認証URLを生成する
  # @param redirect_uri [String] コールバックURL
  # @param state [String] CSRF 対策用の state パラメータ
  # @return [String] 認証URL
  def authorization_url(redirect_uri:, state: nil)
    params = {
      client_id: @client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: SCOPE
    }
    params[:state] = state if state.present?

    "#{AUTHORIZE_ENDPOINT}?#{params.to_query}"
  end

  # 認証コードをアクセストークンに交換する
  # @param code [String] 認証コード
  # @param redirect_uri [String] コールバックURL
  # @return [Hash] トークン情報（access_token, token_type 等）
  def exchange_code(code:, redirect_uri:)
    uri = URI.parse(TOKEN_ENDPOINT)
    response = Net::HTTP.post_form(uri, {
      client_id: @client_id,
      client_secret: @client_secret,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    })

    body = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise TokenExchangeError, "トークン交換に失敗しました: #{body['error_description'] || body['error']}"
    end

    body
  end

  # アクセストークンを使用してユーザー情報を取得する
  # @param access_token [String] アクセストークン
  # @return [Hash] ユーザー情報（id, username, discriminator 等）
  def fetch_user_info(access_token:)
    uri = URI.parse(USERINFO_ENDPOINT)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)

    body = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise UserInfoError, "ユーザー情報の取得に失敗しました: #{body['message'] || body['error']}"
    end

    body
  end
end
