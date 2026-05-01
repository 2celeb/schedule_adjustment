# frozen_string_literal: true

module Api
  # 表示名変更コントローラー
  # メンバーの表示名変更を提供する
  #
  # エンドポイント:
  # - PATCH /api/users/:user_id/display_name — 表示名変更（ゆるい識別 or Cookie）
  class DisplayNamesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_target_user
    before_action :authorize_display_name_change!

    # PATCH /api/users/:user_id/display_name
    # ユーザーの表示名を変更する
    # 本人またはグループの Owner が変更可能
    def update
      display_name = params[:display_name]

      if display_name.blank?
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "表示名が不正です。",
            details: [{ field: "display_name", message: "表示名を入力してください。" }]
          }
        }, status: :bad_request
        return
      end

      if display_name.length > 50
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "表示名が不正です。",
            details: [{ field: "display_name", message: "表示名は50文字以内で入力してください。" }]
          }
        }, status: :bad_request
        return
      end

      @target_user.update!(display_name: display_name)

      render json: {
        user: {
          id: @target_user.id,
          display_name: @target_user.display_name,
          discord_screen_name: @target_user.discord_screen_name
        }
      }
    end

    private

    def set_target_user
      return if performed?

      @target_user = User.find_by(id: params[:user_id])
      return if @target_user

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "ユーザーが見つかりません。"
        }
      }, status: :not_found
    end

    # 表示名変更の権限チェック
    # - 本人であること（ゆるい識別 or Cookie）
    # - または対象ユーザーが所属するグループの Owner であること
    def authorize_display_name_change!
      return if performed?

      identified_user = current_user_or_loose

      # 本人の場合は許可
      return if identified_user && identified_user.id == @target_user.id

      # Owner の場合は許可（対象ユーザーが所属するグループの Owner であること）
      if identified_user
        target_group_ids = @target_user.memberships.pluck(:group_id)
        return if identified_user.owned_groups.where(id: target_group_ids).exists?
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
