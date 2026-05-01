# frozen_string_literal: true

# アプリケーション全体の基底コントローラー
# API モードのため ActionController::API を継承
class ApplicationController < ActionController::API
  include ActionController::Cookies
  include SessionManagement
  include Authentication

  # リクエスト情報を Current に設定する
  # モデル層で変更履歴記録時に User-Agent と IP アドレスを参照するために使用
  before_action :set_request_context

  private

  # Current にリクエスト情報を設定する
  def set_request_context
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
  end
end
