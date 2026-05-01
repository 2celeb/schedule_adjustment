# frozen_string_literal: true

module Oauth
  # Discord OAuth 2.0 認証コントローラー
  # Owner の Discord アカウント確認に使用する
  #
  # フロー:
  # 1. GET /oauth/discord — 認証URLにリダイレクト
  # 2. Discord 認証画面でユーザーが許可
  # 3. GET /oauth/discord/callback — コールバック処理
  #    - 認証コード → トークン交換 → ユーザー情報取得
  #    - discord_user_id でユーザーを照合
  #    - auth_locked=true に更新、セッション Cookie を発行
  #    - フロントエンドにリダイレクト
  class DiscordController < ApplicationController
    # OAuth 開始（GET /oauth/discord）
    # クエリパラメータ:
    #   user_id: 対象ユーザーID（必須）
    def authorize
      user_id = params[:user_id]

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

      # state パラメータに user_id を埋め込む（CSRF 対策 + コールバック時の識別用）
      state = encode_state(user_id: user.id)

      auth_url = oauth_service.authorization_url(
        redirect_uri: callback_url,
        state: state
      )

      redirect_to auth_url, allow_other_host: true
    end

    # OAuth コールバック（GET /oauth/discord/callback）
    # Discord からの認証コードを受け取り、トークン交換 → ユーザー情報取得を行う
    def callback
      # エラーレスポンスの処理
      if params[:error].present?
        redirect_to frontend_error_url("Discord認証がキャンセルされました。"), allow_other_host: true
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
      discord_id = user_info["id"]

      unless discord_id.present?
        redirect_to frontend_error_url("Discordアカウント情報の取得に失敗しました。"), allow_other_host: true
        return
      end

      # Discord アカウントの照合
      # ユーザーに discord_user_id が設定されている場合、一致するか確認
      if user.discord_user_id.present? && user.discord_user_id != discord_id
        redirect_to frontend_error_url("Discordアカウントが一致しません。Bot導入時に登録されたアカウントでログインしてください。"), allow_other_host: true
        return
      end

      # 別のユーザーが同じ discord_user_id を使用していないか確認
      existing_user = User.where(discord_user_id: discord_id).where.not(id: user.id).first
      if existing_user
        redirect_to frontend_error_url("このDiscordアカウントは既に別のユーザーに登録されています。"), allow_other_host: true
        return
      end

      # ユーザー情報を更新
      update_attrs = { auth_locked: true }

      # discord_user_id が未設定の場合は設定する
      update_attrs[:discord_user_id] = discord_id unless user.discord_user_id.present?

      # Discord スクリーン名を更新
      discord_username = user_info["global_name"].presence || user_info["username"]
      update_attrs[:discord_screen_name] = discord_username if discord_username.present?

      user.update!(update_attrs)

      # セッション Cookie を発行
      create_session(user, request)

      # フロントエンドにリダイレクトする（成功）
      redirect_to frontend_success_url, allow_other_host: true

    rescue DiscordOauthService::TokenExchangeError => e
      Rails.logger.error("Discord OAuth トークン交換エラー: #{e.message}")
      redirect_to frontend_error_url("Discord認証に失敗しました。もう一度お試しください。"), allow_other_host: true
    rescue DiscordOauthService::UserInfoError => e
      Rails.logger.error("Discord OAuth ユーザー情報取得エラー: #{e.message}")
      redirect_to frontend_error_url("Discordアカウント情報の取得に失敗しました。"), allow_other_host: true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Discord OAuth ユーザー更新エラー: #{e.message}")
      redirect_to frontend_error_url("ユーザー情報の更新に失敗しました。"), allow_other_host: true
    end

    private

    def oauth_service
      @oauth_service ||= DiscordOauthService.new
    end

    # コールバックURLを生成する
    def callback_url
      url_for(action: :callback, controller: "oauth/discord", only_path: false)
    end

    # state パラメータをエンコードする
    # Base64 エンコードした JSON 文字列を使用
    def encode_state(user_id:)
      payload = { user_id: user_id, nonce: SecureRandom.hex(16) }
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
      "#{base_url}/oauth/callback?status=success&provider=discord"
    end

    # フロントエンドのエラーURLを生成する
    def frontend_error_url(message)
      base_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
      "#{base_url}/oauth/callback?status=error&provider=discord&message=#{ERB::Util.url_encode(message)}"
    end
  end
end
