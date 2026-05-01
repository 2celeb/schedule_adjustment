# frozen_string_literal: true

module Api
  # カレンダー同期コントローラー
  # 「今すぐ同期」ボタンによる強制 FreeBusy 再取得を提供する
  #
  # エンドポイント:
  # - POST /api/groups/:share_token/calendar_sync — 強制同期（キャッシュ無視）
  #
  # 要件: 7.5
  class CalendarSyncsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_group

    # POST /api/groups/:share_token/calendar_sync
    # キャッシュを無視して FreeBusy を強制再取得する
    #
    # Google 連携済みメンバーが存在しない場合は 422 エラーを返す
    # ジョブをキューに投入し、202 Accepted を返す
    def create
      connected_members = find_connected_members
      if connected_members.empty?
        render json: {
          error: {
            code: "NO_CONNECTED_MEMBERS",
            message: "Google カレンダー連携済みのメンバーがいません。"
          }
        }, status: :unprocessable_entity
        return
      end

      # 当月の日付範囲で強制同期ジョブを投入
      date_range_start = Date.current.beginning_of_month.iso8601
      date_range_end = Date.current.end_of_month.iso8601

      FreebusyFetchJob.perform_later(
        @group.id,
        date_range_start,
        date_range_end,
        force: true
      )

      render json: {
        message: "カレンダー同期をキューに追加しました。",
        date_range: {
          start: date_range_start,
          end: date_range_end
        }
      }, status: :accepted
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

    # Google 連携済みメンバーを取得する
    # google_oauth_token が存在するユーザーのみ対象
    #
    # @return [ActiveRecord::Relation<User>] Google 連携済みメンバー
    def find_connected_members
      user_ids = @group.memberships.pluck(:user_id)
      User.where(id: user_ids).where.not(google_oauth_token: nil)
    end
  end
end
