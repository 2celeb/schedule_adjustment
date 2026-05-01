# frozen_string_literal: true

require "net/http"

# Google カレンダー書き込みサービス
#
# 活動日確定時に以下の処理を行う:
# 1. Owner のサブカレンダー自動作成（未作成の場合）
# 2. Owner のサブカレンダーに予定を追加（参加/不参加メンバー一覧付き）
# 3. 書き込み連携メンバーの個人カレンダーに予定を作成
#
# 使用例:
#   service = CalendarWriteService.new(group, event_day)
#   service.call
#
# 要件: 7.7, 7.8, 7.9
class CalendarWriteService
  CALENDAR_API_BASE = "https://www.googleapis.com/calendar/v3"
  TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

  class Error < StandardError; end
  class TokenRefreshError < Error; end
  class CalendarApiError < Error; end

  # @param group [Group] 対象グループ
  # @param event_day [EventDay] 対象の活動日
  def initialize(group, event_day)
    @group = group
    @event_day = event_day
  end

  # 書き込み処理を実行する
  #
  # 1. Owner のサブカレンダーを確認・作成
  # 2. Owner のサブカレンダーに予定を追加
  # 3. 書き込み連携メンバーの個人カレンダーに予定を作成
  #
  # @return [Hash] 実行結果 { owner_event_created: Boolean, member_events_created: Integer, errors: Array }
  def call
    result = { owner_event_created: false, member_events_created: 0, errors: [] }

    # Owner の Google 連携を確認
    owner = @group.owner
    unless owner_has_calendar_scope?(owner)
      result[:errors] << "Owner に calendar スコープがありません"
      return result
    end

    # 1. サブカレンダーの確認・作成
    begin
      ensure_sub_calendar(owner)
    rescue TokenRefreshError, CalendarApiError => e
      result[:errors] << "サブカレンダー作成失敗: #{e.message}"
      Rails.logger.error("[CalendarWriteService] サブカレンダー作成失敗: #{e.message}")
      return result
    end

    # 2. Owner のサブカレンダーに予定を追加
    begin
      create_owner_event(owner)
      result[:owner_event_created] = true
    rescue TokenRefreshError, CalendarApiError => e
      result[:errors] << "Owner 予定作成失敗: #{e.message}"
      Rails.logger.error("[CalendarWriteService] Owner 予定作成失敗: #{e.message}")
    end

    # 3. 書き込み連携メンバーの個人カレンダーに予定を作成
    write_connected_members.each do |member|
      begin
        create_member_event(member)
        result[:member_events_created] += 1
      rescue TokenRefreshError, CalendarApiError => e
        result[:errors] << "メンバー #{member.id} の予定作成失敗: #{e.message}"
        Rails.logger.warn(
          "[CalendarWriteService] メンバー #{member.id} の予定作成失敗: #{e.message}"
        )
        # 個別メンバーの失敗は全体を止めない
      end
    end

    result
  end

  private

  # Owner が calendar スコープを持っているか確認する
  #
  # @param owner [User] Owner ユーザー
  # @return [Boolean]
  def owner_has_calendar_scope?(owner)
    return false if owner.google_oauth_token.blank?
    return false if owner.google_calendar_scope.blank?

    owner.google_calendar_scope == "calendar"
  end

  # サブカレンダーが存在しない場合は作成する
  #
  # @param owner [User] Owner ユーザー
  def ensure_sub_calendar(owner)
    return if @group.google_sub_calendar_id.present?

    calendar_id = create_sub_calendar(owner)
    @group.update!(google_sub_calendar_id: calendar_id)
  end

  # Google Calendar API でサブカレンダーを作成する
  #
  # @param owner [User] Owner ユーザー
  # @return [String] 作成されたカレンダーの ID
  def create_sub_calendar(owner)
    access_token = ensure_valid_token(owner)

    uri = URI.parse("#{CALENDAR_API_BASE}/calendars")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = {
      summary: "#{@group.name} イベント",
      timeZone: @group.timezone || "Asia/Tokyo"
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise CalendarApiError, "サブカレンダー作成 API エラー: #{response.code} #{response.body}"
    end

    data = JSON.parse(response.body)
    data["id"]
  end

  # Owner のサブカレンダーに予定を作成する
  #
  # @param owner [User] Owner ユーザー
  def create_owner_event(owner)
    access_token = ensure_valid_token(owner)
    calendar_id = @group.google_sub_calendar_id

    event_body = build_event_body(include_member_list: true)

    insert_event(access_token, calendar_id, event_body)
  end

  # メンバーの個人カレンダーに予定を作成する
  #
  # @param member [User] 対象メンバー
  def create_member_event(member)
    access_token = ensure_valid_token(member)

    event_body = build_event_body(include_member_list: false)

    insert_event(access_token, "primary", event_body)
  end

  # Google Calendar API でイベントを挿入する
  #
  # @param access_token [String] アクセストークン
  # @param calendar_id [String] カレンダー ID
  # @param event_body [Hash] イベントデータ
  def insert_event(access_token, calendar_id, event_body)
    encoded_calendar_id = ERB::Util.url_encode(calendar_id)
    uri = URI.parse("#{CALENDAR_API_BASE}/calendars/#{encoded_calendar_id}/events")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = event_body.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise CalendarApiError, "イベント作成 API エラー: #{response.code} #{response.body}"
    end

    JSON.parse(response.body)
  end

  # イベントのリクエストボディを構築する
  #
  # @param include_member_list [Boolean] メンバー一覧を説明に含めるか
  # @return [Hash] イベントデータ
  def build_event_body(include_member_list: false)
    timezone = @group.timezone || "Asia/Tokyo"
    start_time = effective_start_time
    end_time = effective_end_time

    event = {
      summary: event_summary,
      start: {
        dateTime: build_datetime(start_time, timezone),
        timeZone: timezone
      },
      "end" => {
        dateTime: build_datetime(end_time, timezone),
        timeZone: timezone
      }
    }

    if include_member_list
      event[:description] = build_event_description
    end

    event
  end

  # イベントのタイトルを返す
  #
  # @return [String] イベント名（グループの event_name またはグループ名）
  def event_summary
    @group.event_name.presence || @group.name
  end

  # 有効な開始時間を返す（EventDay の値、なければグループデフォルト）
  #
  # @return [String] 開始時間（HH:MM 形式）
  def effective_start_time
    format_time(@event_day.start_time) || format_time(@group.default_start_time) || "19:00"
  end

  # 有効な終了時間を返す（EventDay の値、なければグループデフォルト）
  #
  # @return [String] 終了時間（HH:MM 形式）
  def effective_end_time
    format_time(@event_day.end_time) || format_time(@group.default_end_time) || "22:00"
  end

  # Time オブジェクトを HH:MM 形式の文字列に変換する
  #
  # @param time [Time, nil] 時間オブジェクト
  # @return [String, nil] HH:MM 形式の文字列
  def format_time(time)
    return nil if time.nil?

    time.strftime("%H:%M")
  end

  # 日付と時間文字列から ISO 8601 形式の日時文字列を構築する
  #
  # @param time_str [String] HH:MM 形式の時間文字列
  # @param timezone [String] タイムゾーン名
  # @return [String] ISO 8601 形式の日時文字列
  def build_datetime(time_str, timezone)
    hour, minute = time_str.split(":").map(&:to_i)
    tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["Asia/Tokyo"]
    dt = tz.local(@event_day.date.year, @event_day.date.month, @event_day.date.day, hour, minute)
    dt.iso8601
  end

  # イベントの説明文を構築する（参加/不参加メンバー一覧付き）
  #
  # @return [String] イベント説明文
  def build_event_description
    participating = []
    not_participating = []
    undecided = []

    @group.memberships.includes(:user).each do |membership|
      user = membership.user
      name = user.display_name || user.discord_screen_name || "メンバー#{user.id}"

      availability = Availability.find_by(
        user: user,
        group: @group,
        date: @event_day.date
      )

      case availability&.status
      when 1
        participating << name
      when -1
        not_participating << name
      when 0
        undecided << name
      else
        undecided << name
      end
    end

    lines = []
    lines << "【参加メンバー】"
    lines << (participating.any? ? participating.join("、") : "なし")
    lines << ""
    lines << "【不参加メンバー】"
    lines << (not_participating.any? ? not_participating.join("、") : "なし")
    lines << ""
    lines << "【未定・未入力】"
    lines << (undecided.any? ? undecided.join("、") : "なし")

    lines.join("\n")
  end

  # 書き込み連携メンバーを取得する
  # google_calendar_scope が "freebusy_events" または "calendar" のメンバー（Owner を除く）
  #
  # @return [Array<User>] 書き込み連携メンバーの配列
  def write_connected_members
    user_ids = @group.memberships.where.not(user_id: @group.owner_id).pluck(:user_id)
    return [] if user_ids.empty?

    User.where(id: user_ids)
        .where.not(google_oauth_token: nil)
        .where(google_calendar_scope: %w[freebusy_events calendar])
  end

  # アクセストークンが有効であることを確認し、期限切れの場合はリフレッシュする
  # FreebusySyncService と同じパターンを使用
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

    # トークン情報を更新
    current_token_data = JSON.parse(user.google_oauth_token)
    current_token_data["access_token"] = new_access_token
    current_token_data["expires_at"] = new_expires_at
    current_token_data["refresh_token"] = body["refresh_token"] if body["refresh_token"].present?

    user.update!(google_oauth_token: current_token_data.to_json)

    new_access_token
  end
end
