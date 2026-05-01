# frozen_string_literal: true

# 活動日自動確定ジョブ
#
# sidekiq-cron で定期実行され、確定タイミングに達したグループの活動日を自動確定する。
# AutoScheduleService を呼び出して活動日を生成し、confirmed: true に設定する。
# 確定後は Discord チャンネルへの予定一覧投稿を内部 API 経由でトリガーする。
#
# 失敗時は Sidekiq リトライ（最大3回）。全失敗時は Owner に Discord 通知。
#
# 要件: 5.6
class AutoConfirmJob < ApplicationJob
  queue_as :default

  # リトライ設定: 最大3回、指数バックオフ
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # 全リトライ失敗時の処理
  discard_on StandardError do |job, error|
    group_id = job.arguments.first
    Rails.logger.error(
      "[AutoConfirmJob] 全リトライ失敗: group_id=#{group_id}, error=#{error.message}"
    )

    # Owner への Discord 通知（ベストエフォート）
    begin
      notify_owner_failure(group_id, error)
    rescue => e
      Rails.logger.error(
        "[AutoConfirmJob] Owner 通知失敗: group_id=#{group_id}, error=#{e.message}"
      )
    end
  end

  # ジョブ実行
  #
  # @param group_id [Integer] 対象グループ ID（nil の場合は全グループを処理）
  def perform(group_id = nil)
    if group_id
      process_group(group_id)
    else
      process_all_groups
    end
  end

  private

  # 全グループの自動確定を処理する
  # 確定タイミングに達したグループのみ対象
  def process_all_groups
    AutoScheduleRule.includes(:group).find_each do |rule|
      group = rule.group
      next unless should_confirm?(group, rule)

      begin
        process_group(group.id)
      rescue => e
        Rails.logger.error(
          "[AutoConfirmJob] グループ処理失敗: group_id=#{group.id}, error=#{e.message}"
        )
        # 個別グループの失敗は他のグループの処理を止めない
      end
    end
  end

  # 単一グループの自動確定を処理する
  #
  # @param group_id [Integer] 対象グループ ID
  def process_group(group_id)
    group = Group.find_by(id: group_id)
    unless group
      Rails.logger.warn("[AutoConfirmJob] グループが見つかりません: group_id=#{group_id}")
      return
    end

    rule = group.auto_schedule_rule
    unless rule
      Rails.logger.info("[AutoConfirmJob] 自動確定ルールなし: group_id=#{group_id}")
      return
    end

    service = AutoScheduleService.new(group)

    # 次の週の活動日を生成
    target_date = next_target_week_start(rule)
    event_days = service.generate_for_week(target_date)

    # 活動日を確定
    now = Time.current
    event_days.each do |ed|
      ed.update!(confirmed: true, confirmed_at: now)
    end

    Rails.logger.info(
      "[AutoConfirmJob] 活動日確定完了: group_id=#{group_id}, " \
      "dates=#{event_days.map { |ed| ed.date.iso8601 }.join(', ')}"
    )

    # Discord チャンネルへの予定一覧投稿（ベストエフォート）
    notify_discord(group, event_days)
  end

  # 確定タイミングに達しているかを判定する
  #
  # @param group [Group] 対象グループ
  # @param rule [AutoScheduleRule] 自動確定ルール
  # @return [Boolean]
  def should_confirm?(group, rule)
    service = AutoScheduleService.new(group)
    confirm_date = service.confirm_date_for(Date.current + 7.days)
    return false unless confirm_date

    confirm_date == Date.current
  end

  # 次の対象週の開始日を計算する
  #
  # @param rule [AutoScheduleRule] 自動確定ルール
  # @return [Date] 次の週の開始日
  def next_target_week_start(rule)
    wday = rule.week_start_day
    date = Date.current
    date += 1.day until date.wday == wday
    date
  end

  # Discord チャンネルに予定一覧を投稿する（内部 API 経由）
  #
  # @param group [Group] 対象グループ
  # @param event_days [Array<EventDay>] 確定された活動日
  def notify_discord(group, event_days)
    return if event_days.empty?

    discord_config = group.discord_config
    return unless discord_config

    # 内部 API 経由で Discord Bot に通知を依頼
    # Bot 側の通知エンドポイントが実装されたら有効化する
    Rails.logger.info(
      "[AutoConfirmJob] Discord 通知予定: group_id=#{group.id}, " \
      "channel_id=#{discord_config.default_channel_id}"
    )
  rescue => e
    # Discord 通知の失敗はジョブ全体を失敗させない
    Rails.logger.error(
      "[AutoConfirmJob] Discord 通知失敗: group_id=#{group.id}, error=#{e.message}"
    )
  end

  # Owner に自動確定失敗を通知する
  #
  # @param group_id [Integer] 対象グループ ID
  # @param error [StandardError] 発生したエラー
  def self.notify_owner_failure(group_id, error)
    group = Group.find_by(id: group_id)
    return unless group

    discord_config = group.discord_config
    return unless discord_config

    Rails.logger.error(
      "[AutoConfirmJob] Owner 通知: group_id=#{group_id}, " \
      "owner_id=#{group.owner_id}, error=#{error.message}"
    )
    # Bot 側の DM 通知エンドポイントが実装されたら有効化する
  end
end
