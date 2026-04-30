# frozen_string_literal: true

# セッション管理の共通ロジック
# Cookie ベースのセッション認証を提供する
module SessionManagement
  extend ActiveSupport::Concern

  SESSION_COOKIE_NAME = "_session_token"
  SESSION_DURATION = 30.days

  included do
    helper_method :current_user if respond_to?(:helper_method)
  end

  private

  # 現在のセッションからユーザーを取得する
  # セッションが有効な場合は有効期限を自動延長する
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = authenticate_from_session
  end

  # セッション認証を必須とするフィルター
  # 認証失敗時は 401 エラーを返す
  # Cookie セッションのみを受け付ける（X-User-Id ヘッダーは対象外）
  def authenticate_session!
    return if authenticate_from_session

    render json: {
      error: {
        code: "UNAUTHORIZED",
        message: "認証が必要です。ログインしてください。"
      }
    }, status: :unauthorized
  end

  # セッションを作成し Cookie を発行する
  # OAuth 認証成功後に呼び出される
  def create_session(user, request)
    session = user.sessions.create!(
      token: SecureRandom.hex(32),
      expires_at: SESSION_DURATION.from_now,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )

    set_session_cookie(session.token, session.expires_at)
    session
  end

  # セッションを無効化し Cookie を削除する
  def destroy_session
    token = cookies[SESSION_COOKIE_NAME]
    return unless token

    Session.find_by(token: token)&.destroy
    delete_session_cookie
  end

  # Cookie からセッションを検証しユーザーを返す
  def authenticate_from_session
    token = cookies[SESSION_COOKIE_NAME]
    return nil unless token

    session = Session.includes(:user).find_by(token: token)
    return nil unless session
    return expire_session(session) if session.expired?

    # セッション有効期限の自動延長
    extend_session(session)
    session.user
  end

  # セッションの有効期限を延長する
  def extend_session(session)
    session.update!(
      expires_at: SESSION_DURATION.from_now,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    set_session_cookie(session.token, session.expires_at)
  end

  # 期限切れセッションを削除する
  def expire_session(session)
    session.destroy
    delete_session_cookie
    nil
  end

  # HttpOnly Secure Cookie を設定する
  def set_session_cookie(token, expires_at)
    cookies[SESSION_COOKIE_NAME] = {
      value: token,
      httponly: true,
      secure: !Rails.env.development?,
      same_site: :lax,
      expires: expires_at,
      path: "/"
    }
  end

  # セッション Cookie を削除する
  def delete_session_cookie
    cookies.delete(SESSION_COOKIE_NAME, path: "/")
  end
end
