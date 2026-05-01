# frozen_string_literal: true

module Api
  # グループ管理コントローラー
  # グループ情報の取得、設定更新、共通URL再生成を提供する
  #
  # エンドポイント:
  # - GET /api/groups/:share_token — グループ情報取得（認証不要）
  # - PATCH /api/groups/:id — グループ設定更新（Owner のみ、Cookie 認証）
  # - POST /api/groups/:id/regenerate_token — 共通URL再生成（Owner のみ、Cookie 認証）
  class GroupsController < ApplicationController
    before_action :set_group_by_share_token, only: [:show]
    before_action :set_group_by_id, only: [:update, :regenerate_token]
    before_action :authenticate_session!, only: [:update, :regenerate_token]
    before_action :authorize_owner!, only: [:update, :regenerate_token]

    # GET /api/groups/:share_token
    # グループ情報を取得する（認証不要）
    def show
      render json: { group: serialize_group(@group) }
    end

    # PATCH /api/groups/:id
    # グループ設定を更新する（Owner のみ）
    def update
      if group_params.empty?
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "更新するパラメータが指定されていません。"
          }
        }, status: :bad_request
        return
      end

      if @group.update(group_params)
        render json: { group: serialize_group(@group) }
      else
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "グループの更新に失敗しました。",
            details: @group.errors.map { |e| { field: e.attribute.to_s, message: e.message } }
          }
        }, status: :unprocessable_entity
      end
    end

    # POST /api/groups/:id/regenerate_token
    # 共通URLを再生成する（Owner のみ）
    def regenerate_token
      new_token = Nanoid.generate(size: 21)
      @group.update!(share_token: new_token)

      render json: { group: serialize_group(@group) }
    end

    private

    # share_token からグループを取得する（show 用）
    def set_group_by_share_token
      @group = Group.find_by(share_token: params[:share_token])
      return if @group

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "グループが見つかりません。"
        }
      }, status: :not_found
    end

    # ID からグループを取得する（update, regenerate_token 用）
    def set_group_by_id
      @group = Group.find_by(id: params[:id])
      return if @group

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "グループが見つかりません。"
        }
      }, status: :not_found
    end

    # Owner 権限チェック
    # Cookie 認証済みユーザーが対象グループの Owner であることを確認する
    def authorize_owner!
      return if performed?

      session_user = current_user
      return if session_user && @group.owner_id == session_user.id

      render json: {
        error: {
          code: "FORBIDDEN",
          message: "この操作はグループのOwnerのみ実行できます。"
        }
      }, status: :forbidden
    end

    # 更新許可パラメータ
    def group_params
      params.permit(
        :name, :event_name, :timezone,
        :default_start_time, :default_end_time,
        :threshold_n, :threshold_target,
        :ad_enabled, :locale
      )
    end

    # グループ情報のシリアライズ
    def serialize_group(group)
      {
        id: group.id,
        name: group.name,
        event_name: group.event_name,
        owner_id: group.owner_id,
        share_token: group.share_token,
        timezone: group.timezone,
        default_start_time: group.default_start_time&.strftime("%H:%M"),
        default_end_time: group.default_end_time&.strftime("%H:%M"),
        threshold_n: group.threshold_n,
        threshold_target: group.threshold_target,
        ad_enabled: group.ad_enabled,
        locale: group.locale,
        created_at: group.created_at,
        updated_at: group.updated_at
      }
    end
  end
end
