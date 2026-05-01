# frozen_string_literal: true

module Api
  # Google 連携解除コントローラー
  # Google OAuth 連携の解除処理を提供する
  #
  # 解除処理:
  # - auth_locked を false に更新
  # - google_oauth_token、google_account_id、google_calendar_scope を null に更新
  # - 該当ユーザーの calendar_caches レコードを全削除
  # - 該当ユーザーの全セッションを無効化
  class GoogleLinksController < ApplicationController
    before_action :authenticate_session!
    before_action :set_target_user
    before_action :authorize_unlink!

    # DELETE /api/users/:user_id/google_link
    # Google 連携を解除し、ゆるい識別に戻す
    def destroy
      unless @target_user.google_account_id.present?
        render json: {
          error: {
            code: "NOT_LINKED",
            message: "このユーザーはGoogle連携されていません。"
          }
        }, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        # Google 連携情報をクリア
        @target_user.update!(
          auth_locked: false,
          google_oauth_token: nil,
          google_account_id: nil,
          google_calendar_scope: nil
        )

        # calendar_caches レコードを全削除
        @target_user.calendar_caches.delete_all

        # 該当ユーザーの全セッションを無効化
        @target_user.sessions.delete_all
      end

      # リクエスト元のセッション Cookie を削除
      delete_session_cookie

      head :no_content
    end

    private

    def set_target_user
      @target_user = User.find_by(id: params[:user_id])
      return if @target_user

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "ユーザーが見つかりません。"
        }
      }, status: :not_found
    end

    # 連携解除の権限チェック
    # - 本人であること
    # - または対象ユーザーが所属するグループの Owner であること
    def authorize_unlink!
      return if performed?

      session_user = current_user
      return if session_user && session_user.id == @target_user.id

      if session_user
        target_group_ids = @target_user.memberships.pluck(:group_id)
        return if session_user.owned_groups.where(id: target_group_ids).exists?
      end

      render json: {
        error: {
          code: "FORBIDDEN",
          message: "この操作を実行する権限がありません。"
        }
      }, status: :forbidden
    end
  end
end
