# frozen_string_literal: true

# Bot トークン認証ミドルウェア
# Discord Bot → Rails 内部 API のリクエストを認証する
#
# 認証方式:
# Authorization ヘッダーに Bearer トークンを設定する
# トークンは環境変数 INTERNAL_API_TOKEN と照合する
#
# 使用例:
#   class Api::Internal::BaseController < ApplicationController
#     include BotAuthentication
#     before_action :authenticate_bot!
#   end
module BotAuthentication
  extend ActiveSupport::Concern

  private

  # Bot トークン認証フィルター
  # Authorization ヘッダーの Bearer トークンを検証する
  # トークンが無効または未設定の場合は 401 エラーを返す
  def authenticate_bot!
    token = extract_bearer_token
    return if token.present? && valid_bot_token?(token)

    render json: {
      error: {
        code: "UNAUTHORIZED",
        message: "内部APIトークンが無効です。"
      }
    }, status: :unauthorized
  end

  # Authorization ヘッダーから Bearer トークンを抽出する
  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header.present?

    match = header.match(/\ABearer\s+(.+)\z/i)
    match&.[](1)
  end

  # Bot トークンの有効性を検証する
  # 環境変数 INTERNAL_API_TOKEN と一致するかを確認する
  def valid_bot_token?(token)
    expected = ENV["INTERNAL_API_TOKEN"]
    return false if expected.blank?

    ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end
end
