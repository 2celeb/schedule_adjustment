# frozen_string_literal: true

# FreeBusy 取得ジョブ
#
# ページ表示時にキャッシュ切れを検知した場合に非同期実行される。
# FreebusySyncService を呼び出して Google Calendar FreeBusy API から
# 予定有無を取得し、calendar_caches テーブルを更新する。
#
# Google API エラー時はキャッシュを更新せず既存キャッシュを継続使用する。
# トークン期限切れ時はリフレッシュトークンで再取得し、失敗時はユーザーに再認証を促す。
# API レート制限時は指数バックオフでリトライ（最大3回、ApplicationJob の retry_on で対応）。
#
# 要件: 7.4, 7.10
class FreebusyFetchJob < ApplicationJob
  queue_as :default

  # グループが削除された場合はジョブを破棄
  discard_on ActiveRecord::RecordNotFound

  # ジョブ実行
  #
  # @param group_id [Integer] 対象グループ ID
  # @param date_range_start [String] 同期対象の開始日（ISO 8601 形式）
  # @param date_range_end [String] 同期対象の終了日（ISO 8601 形式）
  # @param force [Boolean] true の場合はキャッシュを無視して強制再取得（「今すぐ同期」ボタン用）
  def perform(group_id, date_range_start, date_range_end, force: false)
    group = Group.find(group_id)
    date_range = Date.parse(date_range_start)..Date.parse(date_range_end)

    result = FreebusySyncService.new(group, date_range, force: force).call

    Rails.logger.info(
      "[FreebusyFetchJob] 同期完了: group_id=#{group_id}, " \
      "synced_users=#{result[:synced_users]}, cached_dates=#{result[:cached_dates]}"
    )
  rescue FreebusySyncService::TokenRefreshError => e
    # トークンリフレッシュ失敗時はログ記録のみ（既存キャッシュを継続使用）
    # ユーザーに再認証を促す必要がある
    Rails.logger.warn(
      "[FreebusyFetchJob] トークンリフレッシュ失敗: group_id=#{group_id}, error=#{e.message}"
    )
  rescue FreebusySyncService::FreeBusyApiError => e
    # API エラー時はキャッシュを更新せず既存キャッシュを継続使用
    Rails.logger.warn(
      "[FreebusyFetchJob] FreeBusy API エラー: group_id=#{group_id}, error=#{e.message}"
    )
  end
end
