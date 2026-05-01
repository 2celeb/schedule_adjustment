# frozen_string_literal: true

module Api
  # 参加可否コントローラー
  # 全メンバーの参加可否取得（月単位）と一括更新を提供する
  #
  # エンドポイント:
  # - GET /api/groups/:share_token/availabilities — 全メンバーの参加可否取得（認証不要）
  # - PUT /api/groups/:share_token/availabilities — 参加可否の一括更新（ゆるい識別 or Cookie）
  class AvailabilitiesController < ApplicationController
    before_action :set_group
    before_action :authenticate_user!, only: [:update]

    # GET /api/groups/:share_token/availabilities
    # 全メンバーの参加可否を月単位で取得する（認証不要）
    #
    # パラメータ:
    #   month: 対象月（YYYY-MM 形式、デフォルト: 当月）
    def show
      month = parse_month(params[:month])
      return if performed?

      date_range = month_date_range(month)

      members = load_members
      availabilities = load_availabilities(date_range)
      event_days = load_event_days(date_range)
      summary = build_summary(date_range, members, availabilities)

      render json: {
        group: serialize_group(@group),
        members: members.map { |m| serialize_member(m) },
        availabilities: serialize_availabilities(availabilities, date_range),
        event_days: serialize_event_days(event_days),
        summary: summary
      }
    end

    # PUT /api/groups/:share_token/availabilities
    # 参加可否を一括更新する（upsert）
    #
    # リクエストボディ:
    #   {
    #     "user_id": 42,
    #     "availabilities": [
    #       { "date": "2025-01-06", "status": 1, "comment": null },
    #       { "date": "2025-01-07", "status": -1, "comment": "出張のため" }
    #     ]
    #   }
    def update
      target_user = find_target_user
      return if performed?

      entries = availability_entries
      unless entries.is_a?(Array) && entries.present?
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "availabilities パラメータは配列で指定してください。"
          }
        }, status: :bad_request
        return
      end

      errors = []
      updated = []

      ActiveRecord::Base.transaction do
        entries.each do |entry|
          result = upsert_availability(target_user, entry)
          if result[:error]
            errors << result[:error]
          else
            updated << result[:availability]
          end
        end

        # エラーがあればロールバック
        raise ActiveRecord::Rollback if errors.any?
      end

      if errors.any?
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "参加可否の更新に失敗しました。",
            details: errors
          }
        }, status: :unprocessable_entity
      else
        render json: {
          updated: updated.map { |a| serialize_single_availability(a) }
        }
      end
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

    # 対象月をパースする（YYYY-MM 形式）
    # 不正な形式の場合は 400 エラーを返す
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

    # 月の日付範囲を取得する
    def month_date_range(date)
      date.beginning_of_month..date.end_of_month
    end

    # グループのメンバーを取得する（メンバーシップ経由）
    def load_members
      @group.memberships.includes(:user).order(:created_at)
    end

    # 指定期間の参加可否を取得する
    def load_availabilities(date_range)
      @group.availabilities
            .where(date: date_range)
            .includes(:user)
    end

    # 指定期間の活動日を取得する
    def load_event_days(date_range)
      @group.event_days
            .where(date: date_range)
            .order(:date)
    end

    # 集計データを構築する
    # 各日付の ○/△/×/− の人数を集計
    def build_summary(date_range, members, availabilities)
      total_members = members.size

      # 日付ごとの status をハッシュに整理
      avail_by_date = availabilities.group_by(&:date)

      summary = {}
      date_range.each do |date|
        day_avails = avail_by_date[date] || []
        ok = day_avails.count { |a| a.status == 1 }
        maybe = day_avails.count { |a| a.status == 0 }
        ng = day_avails.count { |a| a.status == -1 }
        none = total_members - ok - maybe - ng

        summary[date.iso8601] = { ok: ok, maybe: maybe, ng: ng, none: none }
      end

      summary
    end

    # 更新対象ユーザーを特定する
    # リクエストの user_id パラメータで指定されたユーザーを検証する
    def find_target_user
      user_id = params[:user_id]
      unless user_id.present?
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "user_id パラメータは必須です。"
          }
        }, status: :bad_request
        return nil
      end

      target_user = User.find_by(id: user_id)
      unless target_user
        render json: {
          error: {
            code: "NOT_FOUND",
            message: "ユーザーが見つかりません。"
          }
        }, status: :not_found
        return nil
      end

      # グループのメンバーであることを確認
      unless @group.memberships.exists?(user_id: target_user.id)
        render json: {
          error: {
            code: "FORBIDDEN",
            message: "このユーザーはグループのメンバーではありません。"
          }
        }, status: :forbidden
        return nil
      end

      # 認証ユーザーが対象ユーザー本人であることを確認
      # （ゆるい識別の場合は X-User-Id で、Cookie の場合はセッションで特定）
      unless current_user_or_loose&.id == target_user.id
        render json: {
          error: {
            code: "FORBIDDEN",
            message: "他のユーザーの参加可否は変更できません。"
          }
        }, status: :forbidden
        return nil
      end

      target_user
    end

    # 参加可否を1件 upsert する
    # @return [Hash] { availability: Availability } or { error: Hash }
    def upsert_availability(user, entry)
      date = parse_entry_date(entry["date"])
      return { error: { field: "date", message: "日付の形式が不正です: #{entry["date"]}" } } unless date

      status = entry["status"]
      status = status.to_i if status.is_a?(String)
      unless [1, 0, -1].include?(status)
        return { error: { field: "status", date: date.iso8601, message: "status は 1, 0, -1 のいずれかを指定してください。" } }
      end

      # 権限チェック（過去日付の制御、auth_locked チェック）
      policy = AvailabilityPolicy.new(user, @group)
      unless policy.update?(date: date, authenticated_via_cookie: authenticated_via_cookie?)
        if date < Date.current
          return { error: { field: "date", date: date.iso8601, message: "過去の日付は変更できません。" } }
        else
          return { error: { field: "auth", date: date.iso8601, message: "この操作にはログインが必要です。" } }
        end
      end

      # コメントの保存制御: status が × (-1) または △ (0) の場合のみコメントを保存
      comment = (status == -1 || status == 0) ? entry["comment"] : nil

      # upsert（既存レコードがあれば更新、なければ作成）
      availability = Availability.find_or_initialize_by(
        user: user,
        group: @group,
        date: date
      )
      availability.status = status
      availability.comment = comment
      availability.auto_synced = false # 手動変更なので auto_synced をリセット
      availability.save!

      { availability: availability }
    rescue ActiveRecord::RecordInvalid => e
      { error: { field: "availability", date: date&.iso8601, message: e.message } }
    end

    # エントリの日付文字列をパースする
    def parse_entry_date(date_str)
      return nil if date_str.blank?

      Date.parse(date_str.to_s)
    rescue Date::Error
      nil
    end

    # availabilities パラメータを配列として取得する
    # JSON リクエストの場合は配列、フォームリクエストの場合はハッシュ（インデックスキー）になるため統一する
    def availability_entries
      raw = params[:availabilities]
      return [] if raw.blank?

      if raw.is_a?(Array)
        raw
      elsif raw.is_a?(ActionController::Parameters)
        raw.values
      else
        []
      end
    end

    # グループ情報のシリアライズ
    def serialize_group(group)
      {
        id: group.id,
        name: group.name,
        event_name: group.event_name,
        locale: group.locale,
        threshold_n: group.threshold_n,
        threshold_target: group.threshold_target,
        default_start_time: group.default_start_time&.strftime("%H:%M"),
        default_end_time: group.default_end_time&.strftime("%H:%M"),
        timezone: group.timezone
      }
    end

    # メンバー情報のシリアライズ
    def serialize_member(membership)
      user = membership.user
      {
        id: user.id,
        display_name: user.display_name,
        discord_screen_name: user.discord_screen_name,
        role: membership.role,
        auth_locked: user.auth_locked
      }
    end

    # 参加可否データのシリアライズ
    # { "2025-01-06" => { "42" => { status: 1, comment: nil, auto_synced: false } } }
    def serialize_availabilities(availabilities, date_range)
      result = {}
      date_range.each { |d| result[d.iso8601] = {} }

      availabilities.each do |a|
        date_key = a.date.iso8601
        result[date_key] ||= {}
        result[date_key][a.user_id.to_s] = {
          status: a.status,
          comment: a.comment,
          auto_synced: a.auto_synced
        }
      end

      result
    end

    # 活動日データのシリアライズ
    def serialize_event_days(event_days)
      result = {}
      event_days.each do |ed|
        start_time = ed.start_time&.strftime("%H:%M") || @group.default_start_time&.strftime("%H:%M")
        end_time = ed.end_time&.strftime("%H:%M") || @group.default_end_time&.strftime("%H:%M")
        custom_time = ed.start_time.present? || ed.end_time.present?

        result[ed.date.iso8601] = {
          start_time: start_time,
          end_time: end_time,
          confirmed: ed.confirmed,
          custom_time: custom_time
        }
      end
      result
    end

    # 単一の参加可否レコードのシリアライズ（更新レスポンス用）
    def serialize_single_availability(availability)
      {
        id: availability.id,
        user_id: availability.user_id,
        date: availability.date.iso8601,
        status: availability.status,
        comment: availability.comment,
        auto_synced: availability.auto_synced
      }
    end
  end
end
