# frozen_string_literal: true

# 2層認証ロジック
# Cookie セッション優先 → X-User-Id ヘッダーフォールバックの認証を提供する
#
# 認証フロー:
# 1. Cookie セッションからユーザーを特定（SessionManagement#authenticate_from_session）
# 2. Cookie がなければ X-User-Id ヘッダーからユーザーを特定
# 3. X-User-Id で特定されたユーザーが auth_locked=true の場合は拒否（Cookie 必須）
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user_or_loose if respond_to?(:helper_method)
  end

  private

  # 現在のユーザーを取得する（2層認証）
  # Cookie セッション → X-User-Id ヘッダーの順で認証を試みる
  # auth_locked=true のユーザーは X-User-Id のみではアクセス不可（nil を返す）
  def current_user_or_loose
    return @current_user_or_loose if defined?(@current_user_or_loose)

    # 1. Cookie セッションからユーザーを特定（優先）
    @current_user_or_loose = authenticate_from_session
    return @current_user_or_loose if @current_user_or_loose

    # 2. X-User-Id ヘッダーからユーザーを特定（フォールバック）
    @current_user_or_loose = authenticate_from_header
  end

  # current_user は current_user_or_loose のエイリアス
  # SessionManagement の current_user をオーバーライドする
  def current_user
    current_user_or_loose
  end

  # ゆるい識別または Cookie 認証を必須とするフィルター
  # auth_locked=true のユーザーが X-User-Id のみでアクセスした場合は AUTH_LOCKED を返す
  # いずれの認証もない場合は UNAUTHORIZED を返す
  def authenticate_user!
    # auth_locked ユーザーが X-User-Id のみでアクセスしている場合を検出
    if auth_locked_header_only?
      render json: {
        error: {
          code: "AUTH_LOCKED",
          message: "このユーザーはGoogle連携済みのため、ログインが必要です。"
        }
      }, status: :unauthorized
      return
    end

    return if current_user_or_loose

    render json: {
      error: {
        code: "UNAUTHORIZED",
        message: "ユーザーの識別ができません。メンバーを選択するか、ログインしてください。"
      }
    }, status: :unauthorized
  end

  # auth_locked ユーザー向けの厳格な認証フィルター
  # Cookie セッションを必須とし、X-User-Id ヘッダーのみでは拒否する
  # auth_locked=false のユーザーは X-User-Id ヘッダーでもアクセス可能
  def authenticate_strict!
    # まず基本認証を実行
    authenticate_user!
    return if performed?

    # current_user_or_loose が返すユーザーが auth_locked の場合、
    # Cookie セッションで認証されていることを確認する
    identified_user = current_user_or_loose
    return unless identified_user&.auth_locked?
    return if authenticated_via_cookie?

    render json: {
      error: {
        code: "AUTH_LOCKED",
        message: "このユーザーはGoogle連携済みのため、ログインが必要です。"
      }
    }, status: :unauthorized
  end

  # Cookie セッションで認証されているかどうかを判定する
  def authenticated_via_cookie?
    token = cookies[SessionManagement::SESSION_COOKIE_NAME]
    return false unless token

    session = Session.find_by(token: token)
    session.present? && !session.expired?
  end

  # X-User-Id ヘッダーからユーザーを特定する
  # auth_locked=true のユーザーは X-User-Id ヘッダーのみではアクセス不可（nil を返す）
  def authenticate_from_header
    user_id = request.headers["X-User-Id"]
    return nil if user_id.blank?

    user = User.find_by(id: user_id)
    return nil unless user

    # auth_locked ユーザーは X-User-Id ヘッダーのみではアクセス不可
    return nil if user.auth_locked?

    user
  end

  # auth_locked=true のユーザーが X-User-Id ヘッダーのみでアクセスしているかを判定する
  # Cookie セッションがなく、X-User-Id で特定されたユーザーが auth_locked の場合に true
  def auth_locked_header_only?
    # Cookie セッションで認証済みなら false
    return false if authenticated_via_cookie?

    user_id = request.headers["X-User-Id"]
    return false if user_id.blank?

    user = User.find_by(id: user_id)
    return false unless user

    user.auth_locked?
  end
end
