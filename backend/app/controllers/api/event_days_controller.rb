# frozen_string_literal: true

module Api
  # 活動日管理コントローラー
  # 活動日の一覧取得、手動追加、更新、削除を提供する
  #
  # エンドポイント:
  # - GET /api/groups/:group_id/event_days — 活動日一覧取得（認証不要）
  # - POST /api/groups/:group_id/event_days — 活動日手動追加（Owner のみ、Cookie 認証）
  # - PATCH /api/event_days/:id — 活動日更新（Owner のみ、Cookie 認証）
  # - DELETE /api/event_days/:id — 活動日削除（Owner のみ、Cookie 認証）
  #
  # 要件: 5.7, 5.8, 5.9
  class EventDaysController < ApplicationController
    before_action :set_group, only: [:index, :create]
    before_action :set_event_day, only: [:update, :destroy]
    before_action :authenticate_session!, only: [:create, :update, :destroy]
    before_action :authorize_owner!, only: [:create, :update, :destroy]

    # GET /api/groups/:group_id/event_days
    # 活動日一覧を取得する（認証不要）
    #
    # パラメータ:
    #   month: 対象月（YYYY-MM 形式、デフォルト: 当月）
    def index
      month = parse_month(params[:month])
      return if performed?

      date_range = month.beginning_of_month..month.end_of_month
      event_days = @group.event_days.where(date: date_range).order(:date)

      render json: {
        event_days: event_days.map { |ed| serialize_event_day(ed) }
      }
    end

    # POST /api/groups/:group_id/event_days
    # 活動日を手動追加する（Owner のみ）
    def create
      event_day = @group.event_days.build(event_day_params)

      if event_day.save
        render json: { event_day: serialize_event_day(event_day) }, status: :created
      else
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "活動日の追加に失敗しました。",
            details: event_day.errors.map { |e| { field: e.attribute.to_s, message: e.message } }
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/event_days/:id
    # 活動日を更新する（Owner のみ）— 活動時間の個別変更
    def update
      if event_day_update_params.empty?
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "更新するパラメータが指定されていません。"
          }
        }, status: :bad_request
        return
      end

      if @event_day.update(event_day_update_params)
        render json: { event_day: serialize_event_day(@event_day) }
      else
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "活動日の更新に失敗しました。",
            details: @event_day.errors.map { |e| { field: e.attribute.to_s, message: e.message } }
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/event_days/:id
    # 活動日を削除する（Owner のみ）
    def destroy
      @event_day.destroy!
      head :no_content
    end

    private

    # group_id からグループを取得する
    def set_group
      @group = Group.find_by(id: params[:group_id])
      return if @group

      render json: {
        error: {
          code: "NOT_FOUND",
          message: "グループが見つかりません。"
        }
      }, status: :not_found
    end

    # ID から活動日を取得する（update, destroy 用）
    def set_event_day
      @event_day = EventDay.find_by(id: params[:id])
      unless @event_day
        render json: {
          error: {
            code: "NOT_FOUND",
            message: "活動日が見つかりません。"
          }
        }, status: :not_found
        return
      end

      # 活動日が属するグループを設定（権限チェック用）
      @group = @event_day.group
    end

    # Owner 権限チェック
    def authorize_owner!
      return if performed?

      policy = EventDayPolicy.new(current_user, @group)
      action = case action_name
               when "create" then policy.create?
               when "update" then policy.update?
               when "destroy" then policy.destroy?
               else false
               end

      return if action

      render json: {
        error: {
          code: "FORBIDDEN",
          message: "この操作はグループのOwnerのみ実行できます。"
        }
      }, status: :forbidden
    end

    # 対象月をパースする（YYYY-MM 形式）
    def parse_month(month_str)
      return Date.current if month_str.blank?

      Date.strptime(month_str, "%Y-%m")
    rescue Date::Error
      render json: {
        error: {
          code: "VALIDATION_ERROR",
          message: "month パラメータの形式が不正です。YYYY-MM 形式で指定してください。"
        }
      }, status: :bad_request
      nil
    end

    # 作成用パラメータ
    def event_day_params
      params.permit(:date, :start_time, :end_time, :confirmed)
    end

    # 更新用パラメータ
    def event_day_update_params
      params.permit(:start_time, :end_time, :confirmed, :confirmed_at)
    end

    # 活動日のシリアライズ
    # start_time/end_time が null の場合はグループのデフォルト値を使用（要件 5.9）
    def serialize_event_day(event_day)
      effective_start = event_day.start_time || @group.default_start_time
      effective_end = event_day.end_time || @group.default_end_time
      custom_time = event_day.start_time.present? || event_day.end_time.present?

      {
        id: event_day.id,
        group_id: event_day.group_id,
        date: event_day.date.iso8601,
        start_time: effective_start&.strftime("%H:%M"),
        end_time: effective_end&.strftime("%H:%M"),
        auto_generated: event_day.auto_generated,
        confirmed: event_day.confirmed,
        confirmed_at: event_day.confirmed_at,
        custom_time: custom_time,
        created_at: event_day.created_at,
        updated_at: event_day.updated_at
      }
    end
  end
end
