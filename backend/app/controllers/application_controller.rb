# frozen_string_literal: true

# アプリケーション全体の基底コントローラー
# API モードのため ActionController::API を継承
class ApplicationController < ActionController::API
  include ActionController::Cookies
  include SessionManagement
  include Authentication
end
