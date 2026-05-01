# frozen_string_literal: true

module Api
  # メンバー管理コントローラー
  # メンバー一覧取得、役割変更を提供する
  #
  # エンドポイント:
  # - GET /api/groups/:share_token/members — メンバー一覧取得（認証不要）
  # - PATCH /api/memberships/:id — メンバー役割変更（Owner のみ、Cookie 認証）
  class MembershipsController < ApplicationController
    before_action :set_group, only: [:index]
    before_action :set_membership, only: [:update]
    before_action :authenticate_session!, only: [:update]
    before_action :authorize_owner!, only: [:update]

    # メンバー上限
    MAX_MEMBERS_PER_GROUP = 20

    # GET /api/groups/:share_token/members
    # グループのメンバー一覧を取得する（認証不要）
    def index
      memberships = @group.memberships.includes(:user).order(:created_at)

      render json: {
        group_id: @group.id,
        members: memberships.map { |m| serialize_membership(m) }
      }
    end

    # PATCH /api/memberships/:id
    # メンバーの役割を変更する（Owner のみ）
    # core / sub の切り替えのみ許可（owner への変更は不可）
    def update
      role = params[:role]

      unless %w[core sub].include?(role)
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "役割の値が不正です。",
            details: [{ field: "role", message: "core または sub を指定してください。" }]
          }
        }, status: :bad_request
        return
      end

      # Owner 自身の役割変更は不可
      if @membership.role == "owner"
        render json: {
          error: {
            code: "FORBIDDEN",
            message: "Ownerの役割は変更できません。"
          }
        }, status: :forbidden
        return
      end

      @membership.update!(role: role)

      render json: { membership: serialize_membership(@membership) }
    end

    private

    # share_token からグループを取得する
    def set_group
      @group = Group.find_by(share_token: params[:group_share_token])
      return if @group

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "グループが見つかりません。"
        }
      }, status: :not_found
    end

    # ID からメンバーシップを取得する
    def set_membership
      @membership = Membership.includes(:user, :group).find_by(id: params[:id])
      return if @membership

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "メンバーシップが見つかりません。"
        }
      }, status: :not_found
    end

    # Owner 権限チェック
    # GroupPolicy を使用して Cookie 認証済みユーザーが対象グループの Owner であることを確認する
    def authorize_owner!
      return if performed?

      policy = GroupPolicy.new(current_user, @membership.group)
      return if policy.update?

      render json: {
        error: {
          code: "FORBIDDEN",
          message: "この操作はグループのOwnerのみ実行できます。"
        }
      }, status: :forbidden
    end

    # メンバーシップのシリアライズ
    def serialize_membership(membership)
      user = membership.user
      {
        id: membership.id,
        user_id: user.id,
        display_name: user.display_name,
        discord_screen_name: user.discord_screen_name,
        role: membership.role,
        auth_locked: user.auth_locked,
        anonymized: user.anonymized
      }
    end
  end
end
