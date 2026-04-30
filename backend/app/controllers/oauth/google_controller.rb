# frozen_string_literal: true

module Oauth
  # Google OAuth 2.0 認証コントローラー
  # メンバーの Google カレンダー連携および Owner の認証を処理する
  #
  # フロー:
  # 1. GET /oauth/google — 認証URLにリダイレクト
  # 2. Google 認証画面でユーザーが許可
  # 3. GET /oauth/google/callback — コールバック処理
  #    - 認証コード → トークン交換 → ユーザー情報取得
  #    - ユーザーの google_account_id を設定、auth_locked=true に更新
  #    - セッション Cookie を発行
  #    - フロントエンドにリダイレクト
  class GoogleController < ApplicationController
    # OAuth 開始（GET /oauth/google）
    # クエリパラメータ:
    #   user_id: 対象ユーザーID（必須）
    #   scope: スコープパターン（freebusy / freebusy_events / calendar）
    def authorize
      user_id = params[:user_id]
      scope_pattern = params[:scope].presence || "freebusy"

      unless user_id.present?
        render json: {
          error: { code: "INVALID_PARAMS", message: "user_id パラメータが必要です。" }
        }, status: :bad_request
        return
      end

      user = User.find_by(id: user_id)
      unless user
        render json: {
          error: { code: "NOT_FOUND", message: "ユーザーが見つかりません。" }
        }, status: :not_found
        return
      end

      # state パラメータに user_id とスコープを埋め込む（CSRF 対策 + コールバック時の識別用）
      state = encode_state(user_id: user.id, scope_pattern: scope_pattern)

      auth_url = oauth_service.authorization_url(
        redirect_uri: callback_url,
        scope_pattern: scope_pattern,
        state: state
      )

      redirect_to auth_url, allow_other_host: true
    end

    # OAuth コールバック（GET /oauth/google/callback）
    # Google からの認証コードを受け取り、トークン交換 → ユーザー情報取得を行う
    def callback
      # エラーレスポンスの処理
      if params[:error].present?
        redirect_to frontend_error_url("Google認証がキャンセルされました。"), allow_other_host: true
        return
      end

      code = params[:code]
      state = params[:state]

      unless code.present? && state.present?
        redirect_to frontend_error_url("認証パラメータが不足しています。"), allow_other_host: true
        return
      end

      # state からユーザー情報を復元
      state_data = decode_state(state)
      unless state_data
        redirect_to frontend_error_url("認証状態が無効です。"), allow_other_host: true
        return
      end

      user = User.find_by(id: state_data[:user_id])
      unless user
        redirect_to frontend_error_url("ユーザーが見つかりません。"), allow_other_host: true
        return
      end

      # トークン交換
      token_data = oauth_service.exchange_code(code: code, redirect_uri: callback_url)

      # ユーザー情報取得
      user_info = oauth_service.fetch_user_info(access_token: token_data["access_token"])
      google_account_id = user_info["sub"]

      unless google_account_id.present?
        redirect_to frontend_error_url("Googleアカウント情報の取得に失敗しました。"), allow_other_host: true
        return
      end

      # Google アカウント一意制約チェック
      # 既に別のユーザーが同じ google_account_id を使用している場合は拒否
      existing_user = User.where(google_account_id: google_account_id).where.not(id: user.id).first
      if existing_user
        redirect_to frontend_error_url("このGoogleアカウントは既に別のユーザーに連携されています。"), allow_other_host: true
        return
      end

      # ユーザーに既に別の google_account_id が設定されている場合は拒否（409 相当）
      if user.google_account_id.present? && user.google_account_id != google_account_id
        redirect_to frontend_error_url("このユーザーは既に別のGoogleアカウントで連携されています。別のGoogleアカウントでの認証はできません。"), allow_other_host: true
        return
      end

      # トークン情報を JSON で保存（access_token, refresh_token, expires_in 等）
      oauth_token_json = {
        access_token: token_data["access_token"],
        refresh_token: token_data["refresh_token"],
        expires_at: Time.current.to_i + (token_data["expires_in"] || 3600).to_i
      }.to_json

      # ユーザー情報を更新
      user.update!(
        google_account_id: google_account_id,
        google_oauth_token: oauth_token_json,
        google_calendar_scope: state_data[:scope_pattern],
        auth_locked: true
      )

      # セッション Cookie を発行
      create_session(user, request)

      # フロントエンドにリダイレクト（成功）
      redirect_to frontend_success_url, allow_other_host: true

    rescue GoogleOauthService::TokenExchangeError => e
      Rails.logger.error("Google OAuth トークン交換エラー: #{e.message}")
      redirect_to frontend_error_url("Google認証に失敗しました。もう一度お試しください。"), allow_other_host: true
    rescue GoogleOauthService::UserInfoError => e
      Rails.logger.error("Google OAuth ユーザー情報取得エラー: #{e.message}")
      redirect_to frontend_error_url("Googleアカウント情報の取得に失敗しました。"), allow_other_host: true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Google OAuth ユーザー更新エラー: #{e.message}")
      redirect_to frontend_error_url("ユーザー情報の更新に失敗しました。"), allow_other_host: true
    end

    private

    def oauth_service
      @oauth_service ||= GoogleOauthService.new
    end

    # コールバックURLを生成する
    def callback_url
      url_for(action: :callback, controller: "oauth/google", only_path: false)
    end

    # state パラメータをエンコードする
    # Base64 エンコードした JSON 文字列を使用
    def encode_state(user_id:, scope_pattern:)
      payload = { user_id: user_id, scope_pattern: scope_pattern, nonce: SecureRandom.hex(16) }
      Base64.urlsafe_encode64(payload.to_json)
    end

    # state パラメータをデコードする
    def decode_state(state)
      json = Base64.urlsafe_decode64(state)
      data = JSON.parse(json, symbolize_names: true)
      return nil unless data[:user_id].present?

      data
    rescue ArgumentError, JSON::ParserError
      nil
    end

    # フロントエンドの成功URLを生成する
    def frontend_success_url
      base_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
      "#{base_url}/oauth/callback?status=success"
    end

    # フロントエンドのエラーURLを生成する
    def frontend_error_url(message)
      base_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
      "#{base_url}/oauth/callback?status=error&message=#{ERB::Util.url_encode(message)}"
    end
  end
end
