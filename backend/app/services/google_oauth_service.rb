# frozen_string_literal: true

# Google OAuth 2.0 認証サービス
# 認証コード取得 → トークン交換 → ユーザー情報取得のフローを管理する
class GoogleOauthService
  TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
  USERINFO_ENDPOINT = "https://www.googleapis.com/oauth2/v3/userinfo"
  AUTHORIZE_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"

  # スコープ定義
  # メンバー向け: 予定枠のみ（FreeBusy）
  SCOPE_FREEBUSY = "https://www.googleapis.com/auth/calendar.freebusy.readonly"
  # メンバー向け: 予定枠 + 書き込み
  SCOPE_FREEBUSY_EVENTS = [
    "https://www.googleapis.com/auth/calendar.freebusy.readonly",
    "https://www.googleapis.com/auth/calendar.events"
  ].join(" ")
  # Owner 向け: フルカレンダーアクセス
  SCOPE_CALENDAR_FULL = "https://www.googleapis.com/auth/calendar"

  # スコープパターンのマッピング
  SCOPE_PATTERNS = {
    "freebusy" => SCOPE_FREEBUSY,
    "freebusy_events" => SCOPE_FREEBUSY_EVENTS,
    "calendar" => SCOPE_CALENDAR_FULL
  }.freeze

  class Error < StandardError; end
  class TokenExchangeError < Error; end
  class UserInfoError < Error; end

  def initialize
    @client_id = ENV.fetch("GOOGLE_CLIENT_ID")
    @client_secret = ENV.fetch("GOOGLE_CLIENT_SECRET")
  end

  # Google OAuth 認証URLを生成する
  # @param redirect_uri [String] コールバックURL
  # @param scope_pattern [String] スコープパターン（freebusy / freebusy_events / calendar）
  # @param state [String] CSRF 対策用の state パラメータ
  # @return [String] 認証URL
  def authorization_url(redirect_uri:, scope_pattern: "freebusy", state: nil)
    scope = SCOPE_PATTERNS.fetch(scope_pattern, SCOPE_FREEBUSY)

    params = {
      client_id: @client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "openid email #{scope}",
      access_type: "offline",
      prompt: "consent"
    }
    params[:state] = state if state.present?

    "#{AUTHORIZE_ENDPOINT}?#{params.to_query}"
  end

  # 認証コードをアクセストークンに交換する
  # @param code [String] 認証コード
  # @param redirect_uri [String] コールバックURL
  # @return [Hash] トークン情報（access_token, refresh_token, expires_in 等）
  def exchange_code(code:, redirect_uri:)
    uri = URI.parse(TOKEN_ENDPOINT)
    response = Net::HTTP.post_form(uri, {
      code: code,
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    })

    body = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise TokenExchangeError, "トークン交換に失敗しました: #{body['error_description'] || body['error']}"
    end

    body
  end

  # アクセストークンを使用してユーザー情報を取得する
  # @param access_token [String] アクセストークン
  # @return [Hash] ユーザー情報（sub, email 等）
  def fetch_user_info(access_token:)
    uri = URI.parse(USERINFO_ENDPOINT)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)

    body = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise UserInfoError, "ユーザー情報の取得に失敗しました: #{body['error_description'] || body['error']}"
    end

    body
  end
end
