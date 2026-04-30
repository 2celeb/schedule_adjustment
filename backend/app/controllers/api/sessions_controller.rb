# frozen_string_literal: true

module Api
  # セッション管理コントローラー
  # ログアウト機能を提供する
  class SessionsController < ApplicationController
    before_action :authenticate_session!, only: [:destroy]

    # DELETE /api/sessions
    # ログアウト: セッションを無効化し Cookie を削除する
    def destroy
      destroy_session
      head :no_content
    end
  end
end
