# frozen_string_literal: true

require 'net/http'

# 活動日当日通知ジョブ
#
# 活動日当日の指定時間（デフォルト: 活動開始8時間前）に実行し、
# 設定チャンネルに「本日活動日です」メッセージを投稿する。
# メンションなし、ユーザー名は記載。
#
# メッセージ内容は auto_schedule_rules.activity_notify_message で変更可能。
# 投稿チャンネルは auto_schedule_rules.activity_notify_channel_id で変更可能。
# 失敗時はリトライ、通知チャンネル無効時はデフォルトチャンネルにフォールバック。
#
# 要件: 6.4, 6.5, 6.6, 6.7
class DailyNotifyJob < ApplicationJob
  queue_as :default

  # リトライ設定: 最大3回、指数バックオフ
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # 全リトライ失敗時の処理
  discard_on StandardError do |job, error|
    group_id = job.arguments.first
    Rails.logger.error(
      "[DailyNotifyJob] 全リトライ失敗: group_id=#{group_id}, error=#{error.message}"
    )
  end

  # ジョブ実行
  #
  # @param group_id [Integer, nil] 対象グループ ID（nil の場合は全グループを処理）
  def perform(group_id = nil)
    if group_id
      process_group(group_id)
    else
      process_all_groups
    end
  end

  private

  # 全グループの当日通知を処理する
  def process_all_groups
    # 本日の活動日を持つグループを検索
    today = Date.current
    event_days = EventDay.includes(group: [:discord_config, :auto_schedule_rule, { memberships: :user }])
                         .where(date: today, confirmed: true)

    event_days.find_each do |event_day|
      group = event_day.group
      next unless group.discord_config

      begin
        process_group_event_day(group, event_day)
      rescue => e
        Rails.logger.error(
          "[DailyNotifyJob] グループ処理失敗: group_id=#{group.id}, error=#{e.message}"
        )
      end
    end
  end

  # 単一グループの当日通知を処理する
  #
  # @param group_id [Integer] 対象グループ ID
  def process_group(group_id)
    group = Group.includes(:discord_config, :auto_schedule_rule, memberships: :user)
                 .find_by(id: group_id)

    unless group
      Rails.logger.warn("[DailyNotifyJob] グループが見つかりません: group_id=#{group_id}")
      return
    end

    today = Date.current
    event_day = group.event_days.find_by(date: today, confirmed: true)

    unless event_day
      Rails.logger.info(
        "[DailyNotifyJob] 本日の確定済み活動日なし: group_id=#{group_id}"
      )
      return
    end

    process_group_event_day(group, event_day)
  end

  # グループの活動日当日通知を処理する
  #
  # @param group [Group] 対象グループ
  # @param event_day [EventDay] 本日の活動日
  def process_group_event_day(group, event_day)
    discord_config = group.discord_config
    unless discord_config
      Rails.logger.info("[DailyNotifyJob] Discord 設定なし: group_id=#{group.id}")
      return
    end

    rule = group.auto_schedule_rule

    # 通知チャンネル: activity_notify_channel_id → remind_channel_id → default_channel_id
    channel_id = rule&.activity_notify_channel_id.presence ||
                 discord_config.remind_channel_id.presence ||
                 discord_config.default_channel_id

    unless channel_id.present?
      Rails.logger.warn(
        "[DailyNotifyJob] 通知チャンネルが設定されていません: group_id=#{group.id}"
      )
      return
    end

    # 活動時間の取得（デフォルト値のフォールバック）
    start_time = event_day.start_time || group.default_start_time
    end_time = event_day.end_time || group.default_end_time

    # メンバーの参加可否を取得
    availabilities = group.availabilities
                         .where(date: event_day.date)
                         .includes(:user)
                         .index_by(&:user_id)

    members_data = group.memberships.includes(:user).map do |membership|
      user = membership.user
      avail = availabilities[user.id]
      {
        display_name: user.display_name,
        discord_user_id: user.discord_user_id,
        role: membership.role,
        status: avail&.status
      }
    end

    # カスタムメッセージ（設定されていない場合はデフォルト）
    custom_message = rule&.activity_notify_message

    payload = {
      group_id: group.id,
      channel_id: channel_id,
      type: "daily_notify",
      group_name: group.name,
      event_name: group.event_name,
      date: event_day.date.iso8601,
      start_time: start_time&.strftime("%H:%M"),
      end_time: end_time&.strftime("%H:%M"),
      custom_message: custom_message,
      members: members_data,
      share_token: group.share_token
    }

    notify_bot("daily", payload)

    Rails.logger.info(
      "[DailyNotifyJob] 当日通知送信: group_id=#{group.id}, " \
      "channel_id=#{channel_id}, date=#{event_day.date.iso8601}"
    )
  end

  # Discord Bot の内部 API に通知を送信する
  #
  # @param endpoint [String] 通知エンドポイント名
  # @param payload [Hash] 通知ペイロード
  def notify_bot(endpoint, payload)
    bot_url = ENV.fetch("BOT_INTERNAL_URL", "http://bot:3001")
    uri = URI.parse("#{bot_url}/notifications/#{endpoint}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{ENV.fetch('INTERNAL_API_TOKEN', '')}"
    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error(
        "[DailyNotifyJob] Bot 通知失敗: endpoint=#{endpoint}, " \
        "status=#{response.code}, body=#{response.body}"
      )
    end
  rescue => e
    Rails.logger.error(
      "[DailyNotifyJob] Bot 通知エラー: endpoint=#{endpoint}, error=#{e.message}"
    )
  end
end
