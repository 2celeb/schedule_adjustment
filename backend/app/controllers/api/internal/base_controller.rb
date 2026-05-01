# frozen_string_literal: true

module Api
  module Internal
    # 内部 API の基底コントローラー
    # Discord Bot → Rails の通信で使用する
    # Bot トークン認証を全アクションに適用する
    #
    # 通常の ApplicationController の認証（Cookie / X-User-Id）は使用せず、
    # BotAuthentication による Bearer トークン認証のみを使用する
    class BaseController < ActionController::API
      include BotAuthentication

      before_action :authenticate_bot!
      before_action :set_request_context

      private

      # Current にリクエスト情報を設定する
      def set_request_context
        Current.user_agent = request.user_agent
        Current.ip_address = request.remote_ip
      end
    end
  end
end
