# frozen_string_literal: true

require 'net/http'

# リマインドジョブ
#
# 確定日の N 日前（remind_days_before_confirm）にリマインド通知を送信する。
# 1回目: 設定チャンネルに未入力メンバーへのメンション付きメッセージを投稿
# 2回目（翌日）: まだ未入力のメンバーに DM で個別通知
#
# DM 送信失敗時はスキップしてログ記録、チャンネル通知は必ず実行する。
#
# sidekiq-cron で毎日実行され、リマインド対象のグループを自動検出する。
# 特定グループ ID を指定して個別実行も可能。
#
# 要件: 6.1, 6.2, 6.3
class RemindJob < ApplicationJob
  queue_as :default

  # リトライ設定: 最大3回、指数バックオフ
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # 全リトライ失敗時の処理
  discard_on StandardError do |job, error|
    group_id = job.arguments.first
    Rails.logger.error(
      "[RemindJob] 全リトライ失敗: group_id=#{group_id}, error=#{error.message}"
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

  # 全グループのリマインドを処理する
  def process_all_groups
    AutoScheduleRule.includes(group: [:discord_config, :memberships]).find_each do |rule|
      group = rule.group
      next unless group.discord_config

      begin
        process_group(group.id)
      rescue => e
        Rails.logger.error(
          "[RemindJob] グループ処理失敗: group_id=#{group.id}, error=#{e.message}"
        )
      end
    end
  end

  # 単一グループのリマインドを処理する
  #
  # @param group_id [Integer] 対象グループ ID
  def process_group(group_id)
    group = Group.includes(:discord_config, :auto_schedule_rule, memberships: :user)
                 .find_by(id: group_id)

    unless group
      Rails.logger.warn("[RemindJob] グループが見つかりません: group_id=#{group_id}")
      return
    end

    rule = group.auto_schedule_rule
    unless rule
      Rails.logger.info("[RemindJob] 自動確定ルールなし: group_id=#{group_id}")
      return
    end

    discord_config = group.discord_config
    unless discord_config
      Rails.logger.info("[RemindJob] Discord 設定なし: group_id=#{group_id}")
      return
    end

    # リマインド対象の週を特定
    service = AutoScheduleService.new(group)
    target_week_start = service.next_week_start(Date.current)
    return unless target_week_start

    confirm_date = service.confirm_date_for(target_week_start)
    return unless confirm_date

    remind_start_date = confirm_date - (rule.remind_days_before_confirm || 2).days

    # リマインド対象日かどうかを判定
    today = Date.current
    return unless today >= remind_start_date && today <= confirm_date

    # リマインド日数（1回目 or 2回目）
    days_since_remind_start = (today - remind_start_date).to_i

    # 対象週の日付範囲
    week_end = target_week_start + 6.days
    week_range = target_week_start..week_end

    # 未入力メンバーを取得
    unfilled_members = find_unfilled_members(group, week_range)

    if unfilled_members.empty?
      Rails.logger.info(
        "[RemindJob] 未入力メンバーなし: group_id=#{group_id}"
      )
      return
    end

    # リマインド通知チャンネル（remind_channel_id が設定されていればそちらを使用）
    channel_id = discord_config.remind_channel_id.presence || discord_config.default_channel_id

    if days_since_remind_start == 0
      # 1回目: チャンネルにメンション付きメッセージを投稿
      send_channel_remind(group, channel_id, unfilled_members, week_range)
    else
      # 2回目以降: DM で個別通知
      send_dm_remind(group, channel_id, unfilled_members, week_range)
    end
  end

  # 未入力メンバーを取得する
  #
  # @param group [Group] 対象グループ
  # @param week_range [Range<Date>] 対象週の日付範囲
  # @return [Array<User>] 未入力メンバーの配列
  def find_unfilled_members(group, week_range)
    # 全メンバーを取得
    members = group.memberships.includes(:user).map(&:user)

    # 対象週に1日でも入力がないメンバーを抽出
    members.select do |user|
      filled_dates = group.availabilities
                         .where(user: user, date: week_range)
                         .where.not(status: nil)
                         .pluck(:date)

      filled_dates.size < week_range.count
    end
  end

  # チャンネルにリマインドメッセージを投稿する（1回目）
  #
  # @param group [Group] 対象グループ
  # @param channel_id [String] 投稿先チャンネル ID
  # @param unfilled_members [Array<User>] 未入力メンバー
  # @param week_range [Range<Date>] 対象週の日付範囲
  def send_channel_remind(group, channel_id, unfilled_members, week_range)
    discord_config = group.discord_config
    return unless discord_config && channel_id.present?

    # 未入力メンバーの Discord ユーザー ID を収集（メンション用）
    discord_user_ids = unfilled_members
                         .filter_map(&:discord_user_id)

    payload = {
      group_id: group.id,
      channel_id: channel_id,
      type: "channel_remind",
      week_start: week_range.first.iso8601,
      week_end: week_range.last.iso8601,
      unfilled_discord_user_ids: discord_user_ids,
      unfilled_member_names: unfilled_members.map(&:display_name),
      group_name: group.name,
      share_token: group.share_token
    }

    notify_bot("remind", payload)

    Rails.logger.info(
      "[RemindJob] チャンネルリマインド送信: group_id=#{group.id}, " \
      "channel_id=#{channel_id}, unfilled=#{unfilled_members.size}名"
    )
  end

  # DM でリマインドを送信する（2回目）
  #
  # @param group [Group] 対象グループ
  # @param channel_id [String] フォールバック用チャンネル ID
  # @param unfilled_members [Array<User>] 未入力メンバー
  # @param week_range [Range<Date>] 対象週の日付範囲
  def send_dm_remind(group, channel_id, unfilled_members, week_range)
    # DM 対象: Discord ユーザー ID を持つメンバーのみ
    dm_targets = unfilled_members.select { |u| u.discord_user_id.present? }

    payload = {
      group_id: group.id,
      channel_id: channel_id,
      type: "dm_remind",
      week_start: week_range.first.iso8601,
      week_end: week_range.last.iso8601,
      dm_targets: dm_targets.map { |u|
        {
          discord_user_id: u.discord_user_id,
          display_name: u.display_name
        }
      },
      group_name: group.name,
      share_token: group.share_token
    }

    notify_bot("remind", payload)

    Rails.logger.info(
      "[RemindJob] DM リマインド送信: group_id=#{group.id}, " \
      "dm_targets=#{dm_targets.size}名"
    )
  end

  # Discord Bot の内部 API に通知を送信する
  #
  # @param endpoint [String] 通知エンドポイント名（"remind" or "daily"）
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
        "[RemindJob] Bot 通知失敗: endpoint=#{endpoint}, " \
        "status=#{response.code}, body=#{response.body}"
      )
    end
  rescue => e
    Rails.logger.error(
      "[RemindJob] Bot 通知エラー: endpoint=#{endpoint}, error=#{e.message}"
    )
  end
end
