# frozen_string_literal: true

module Api
  # 自動確定ルールコントローラー
  # グループの自動確定ルールの取得・更新を提供する
  #
  # エンドポイント:
  # - GET /api/groups/:group_id/auto_schedule_rule — ルール取得（Owner のみ、Cookie 認証）
  # - PUT /api/groups/:group_id/auto_schedule_rule — ルール更新（Owner のみ、Cookie 認証）
  #
  # 要件: 5.2, 5.3, 5.4, 5.5
  class AutoScheduleRulesController < ApplicationController
    before_action :set_group
    before_action :authenticate_session!
    before_action :authorize_owner!

    # GET /api/groups/:group_id/auto_schedule_rule
    # 自動確定ルールを取得する（Owner のみ）
    # ルールが存在しない場合はデフォルト値で返す
    def show
      rule = @group.auto_schedule_rule || @group.build_auto_schedule_rule

      render json: { auto_schedule_rule: serialize_rule(rule) }
    end

    # PUT /api/groups/:group_id/auto_schedule_rule
    # 自動確定ルールを更新する（Owner のみ）
    # ルールが存在しない場合は新規作成する
    def update
      rule = @group.auto_schedule_rule || @group.build_auto_schedule_rule

      if rule.update(rule_params)
        render json: { auto_schedule_rule: serialize_rule(rule) }
      else
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "自動確定ルールの更新に失敗しました。",
            details: rule.errors.map { |e| { field: e.attribute.to_s, message: e.message } }
          }
        }, status: :unprocessable_entity
      end
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

    # Owner 権限チェック
    def authorize_owner!
      return if performed?

      policy = GroupPolicy.new(current_user, @group)
      return if policy.update?

      render json: {
        error: {
          code: "FORBIDDEN",
          message: "この操作はグループのOwnerのみ実行できます。"
        }
      }, status: :forbidden
    end

    # 更新許可パラメータ
    def rule_params
      params.permit(
        :max_days_per_week,
        :min_days_per_week,
        :week_start_day,
        :confirm_days_before,
        :remind_days_before_confirm,
        :confirm_time,
        :activity_notify_hours_before,
        :activity_notify_channel_id,
        :activity_notify_message,
        deprioritized_days: [],
        excluded_days: []
      )
    end

    # ルールのシリアライズ
    # confirm_time は time 型（時刻のみ）のため UTC で表示する
    # PostgreSQL の time 型はタイムゾーンなしで保存されるが、
    # Rails が読み込み時にアプリケーションタイムゾーンを適用するため、
    # UTC に変換して本来の値を返す
    def serialize_rule(rule)
      {
        id: rule.id,
        group_id: rule.group_id,
        max_days_per_week: rule.max_days_per_week,
        min_days_per_week: rule.min_days_per_week,
        deprioritized_days: rule.deprioritized_days || [],
        excluded_days: rule.excluded_days || [],
        week_start_day: rule.week_start_day,
        confirm_days_before: rule.confirm_days_before,
        remind_days_before_confirm: rule.remind_days_before_confirm,
        confirm_time: format_time_column(rule.confirm_time),
        activity_notify_hours_before: rule.activity_notify_hours_before,
        activity_notify_channel_id: rule.activity_notify_channel_id,
        activity_notify_message: rule.activity_notify_message,
        created_at: rule.created_at,
        updated_at: rule.updated_at
      }
    end

    # time 型カラムの値を HH:MM 形式でフォーマットする
    # モデル側で UTC として返されるため、そのまま strftime で変換する
    def format_time_column(time_value)
      return nil unless time_value

      time_value.strftime("%H:%M")
    end
  end
end
