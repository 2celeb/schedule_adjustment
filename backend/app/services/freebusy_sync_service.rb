# frozen_string_literal: true

require "net/http"

# FreeBusy 同期サービス
#
# Google Calendar FreeBusy API で連携済みメンバー全員分の予定有無を一括取得し、
# calendar_caches テーブルに has_event（boolean のみ）を保存する。
# 予定のタイトル・詳細・参加者等は一切取得・保存しない（プライバシー重視）。
#
# has_event=true の日の Availability を自動的に ×（status=-1）に設定し、
# auto_synced=true をマークする。メンバーが手動で変更済み（auto_synced=false）の場合は上書きしない。
#
# 使用例:
#   service = FreebusySyncService.new(group, Date.today..Date.today + 30)
#   service.call
#
# 要件: 7.2, 7.3, 7.4, 3.5, 3.6, 10.1
class FreebusySyncService
  FREEBUSY_API_URL = "https://www.googleapis.com/calendar/v3/freeBusy"
  TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

  class Error < StandardError; end
  class TokenRefreshError < Error; end
  class FreeBusyApiError < Error; end

  # @param group [Group] 対象グループ
  # @param date_range [Range<Date>] 同期対象の日付範囲
  # @param force [Boolean] true の場合はキャッシュを無視して強制再取得
  def initialize(group, date_range, force: false)
    @group = group
    @date_range = date_range
    @force = force
  end

  # 同期を実行する
  #
  # 1. Google 連携済みメンバーを取得
  # 2. キャッシュが有効なメンバーをスキップ（force=true の場合は全員対象）
  # 3. FreeBusy API で予定有無を一括取得
  # 4. calendar_caches テーブルに保存
  # 5. has_event=true の日の Availability を自動×に設定
  #
  # @return [Hash] 同期結果 { synced_users: Integer, cached_dates: Integer }
  def call
    connected_members = find_connected_members
    return { synced_users: 0, cached_dates: 0 } if connected_members.empty?

    total_cached = 0

    connected_members.each do |user|
      # キャッシュが有効な場合はスキップ（force=true の場合は常に再取得）
      next if !@force && cache_fresh?(user)

      begin
        busy_dates = fetch_freebusy_for_user(user)
        update_caches(user, busy_dates)
        apply_auto_sync(user, busy_dates)
        total_cached += @date_range.count
      rescue TokenRefreshError => e
        Rails.logger.warn("FreeBusy 同期: ユーザー #{user.id} のトークンリフレッシュに失敗: #{e.message}")
        # トークンリフレッシュ失敗時はスキップ（既存キャッシュを継続使用）
      rescue FreeBusyApiError => e
        Rails.logger.warn("FreeBusy 同期: ユーザー #{user.id} の API 呼び出しに失敗: #{e.message}")
        # API エラー時はスキップ（既存キャッシュを継続使用）
      end
    end

    { synced_users: connected_members.size, cached_dates: total_cached }
  end

  private

  # Google 連携済みメンバーを取得する
  # google_oauth_token が存在するユーザーのみ対象
  #
  # @return [Array<User>] Google 連携済みメンバーの配列
  def find_connected_members
    user_ids = @group.memberships.pluck(:user_id)
    User.where(id: user_ids)
        .where.not(google_oauth_token: nil)
  end

  # ユーザーのキャッシュが有効かどうかを判定する
  # 対象期間の全日付のキャッシュが存在し、かつ全て有効期限内であれば true
  #
  # @param user [User] 対象ユーザー
  # @return [Boolean] キャッシュが有効な場合 true
  def cache_fresh?(user)
    caches = CalendarCache.where(
      user: user,
      group: @group,
      date: @date_range
    )

    return false if caches.count < @date_range.count

    caches.none?(&:stale?)
  end

  # Google Calendar FreeBusy API で予定有無を取得する
  #
  # @param user [User] 対象ユーザー
  # @return [Set<Date>] 予定がある日付の集合
  def fetch_freebusy_for_user(user)
    access_token = ensure_valid_token(user)

    time_min = @date_range.first.beginning_of_day.iso8601
    time_max = (@date_range.last + 1.day).beginning_of_day.iso8601

    request_body = {
      timeMin: time_min,
      timeMax: time_max,
      timeZone: @group.timezone || "Asia/Tokyo",
      items: [{ id: "primary" }]
    }.to_json

    uri = URI.parse(FREEBUSY_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = request_body

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise FreeBusyApiError, "FreeBusy API エラー: #{response.code} #{response.body}"
    end

    parse_freebusy_response(response.body)
  end

  # FreeBusy API レスポンスをパースし、予定がある日付の集合を返す
  # 予定のタイトル・詳細・参加者等は一切取得しない（プライバシー重視）
  #
  # @param response_body [String] API レスポンスの JSON 文字列
  # @return [Set<Date>] 予定がある日付の集合
  def parse_freebusy_response(response_body)
    data = JSON.parse(response_body)
    busy_dates = Set.new

    calendars = data["calendars"] || {}
    calendars.each_value do |calendar_data|
      busy_periods = calendar_data["busy"] || []
      busy_periods.each do |period|
        start_time = Time.parse(period["start"])
        end_time = Time.parse(period["end"])

        # busy 期間に含まれる全日付を追加
        current_date = start_time.to_date
        last_date = end_time.to_date
        # 終了時刻がちょうど日の境界（00:00:00）の場合は前日まで
        last_date -= 1.day if end_time == end_time.beginning_of_day

        while current_date <= last_date
          busy_dates.add(current_date) if @date_range.cover?(current_date)
          current_date += 1.day
        end
      end
    end

    busy_dates
  end

  # calendar_caches テーブルを更新する
  # has_event（boolean）のみを保存 — 予定の詳細は一切保存しない
  #
  # @param user [User] 対象ユーザー
  # @param busy_dates [Set<Date>] 予定がある日付の集合
  def update_caches(user, busy_dates)
    now = Time.current

    @date_range.each do |date|
      cache = CalendarCache.find_or_initialize_by(
        user: user,
        group: @group,
        date: date
      )
      cache.has_event = busy_dates.include?(date)
      cache.fetched_at = now
      cache.save!
    end
  end

  # has_event=true の日の Availability を自動的に ×（status=-1）に設定する
  # auto_synced=true をマークする
  # メンバーが手動で変更済み（auto_synced=false かつ status が nil でない）の場合は上書きしない
  #
  # @param user [User] 対象ユーザー
  # @param busy_dates [Set<Date>] 予定がある日付の集合
  def apply_auto_sync(user, busy_dates)
    @date_range.each do |date|
      has_event = busy_dates.include?(date)

      availability = Availability.find_or_initialize_by(
        user: user,
        group: @group,
        date: date
      )

      if has_event
        # 手動変更済みの場合はスキップ
        # auto_synced=false かつ status が nil でない場合は手動変更とみなす
        next if !availability.new_record? && !availability.auto_synced? && !availability.status.nil?

        availability.status = -1
        availability.auto_synced = true
        availability.save!
      else
        # 予定がない日で、auto_synced=true の ×（自動設定）がある場合はクリア
        if !availability.new_record? && availability.auto_synced? && availability.status == -1
          availability.status = nil
          availability.auto_synced = false
          availability.save!
        end
      end
    end
  end

  # アクセストークンが有効であることを確認し、期限切れの場合はリフレッシュする
  #
  # @param user [User] 対象ユーザー
  # @return [String] 有効なアクセストークン
  def ensure_valid_token(user)
    token_data = JSON.parse(user.google_oauth_token)
    access_token = token_data["access_token"]
    refresh_token = token_data["refresh_token"]
    expires_at = token_data["expires_at"].to_i

    # トークンが有効期限内であればそのまま返す（60秒のバッファ）
    return access_token if Time.current.to_i < (expires_at - 60)

    # リフレッシュトークンで再取得
    refresh_access_token(user, refresh_token)
  end

  # リフレッシュトークンを使用してアクセストークンを再取得する
  #
  # @param user [User] 対象ユーザー
  # @param refresh_token [String] リフレッシュトークン
  # @return [String] 新しいアクセストークン
  def refresh_access_token(user, refresh_token)
    raise TokenRefreshError, "リフレッシュトークンがありません" if refresh_token.blank?

    uri = URI.parse(TOKEN_ENDPOINT)
    response = Net::HTTP.post_form(uri, {
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    })

    body = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise TokenRefreshError, "トークンリフレッシュに失敗: #{body['error_description'] || body['error']}"
    end

    new_access_token = body["access_token"]
    new_expires_at = Time.current.to_i + (body["expires_in"] || 3600).to_i

    # トークン情報を更新（refresh_token は変わらない場合がある）
    current_token_data = JSON.parse(user.google_oauth_token)
    current_token_data["access_token"] = new_access_token
    current_token_data["expires_at"] = new_expires_at
    current_token_data["refresh_token"] = body["refresh_token"] if body["refresh_token"].present?

    user.update!(google_oauth_token: current_token_data.to_json)

    new_access_token
  end
end
