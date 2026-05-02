# frozen_string_literal: true

require "rails_helper"
require "rantly"
require "rantly/property"

# Feature: schedule-management-tool, Property 17: 退会メンバーの匿名化・可視性制御
#
# 任意の退会処理されたメンバーについて、以下が全て成り立つことを検証する:
# - anonymized=true である
# - display_name が匿名化形式（「退会済みメンバーX」）である
# - google_oauth_token と discord_user_id が null である
# - availabilities レコードは削除されず保持されている
# - 一般メンバーからは退会メンバーのデータが非表示である
# - Owner からは退会メンバーのデータが閲覧可能である
#
# Validates: 要件 10.4, 10.5, 10.6
RSpec.describe "Property 17: 退会メンバーの匿名化・可視性制御", type: :request do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  # --- テストデータのセットアップ ---

  let!(:owner) { create(:user, :with_discord, display_name: "オーナー") }
  let!(:group) do
    create(:group, :with_times, owner: owner, name: "テストグループ", locale: "ja")
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }
  let!(:owner_session) { create(:session, user: owner) }

  let!(:active_member) { create(:user, :with_discord, display_name: "アクティブメンバー") }
  let!(:active_membership) { create(:membership, :core, user: active_member, group: group) }

  # 未来の日付を生成する
  def future_date(offset)
    Date.current + offset.days
  end

  describe "匿名化処理の正確性" do
    it "任意の退会メンバーについて、anonymized=true かつ display_name が匿名化形式になる" do
      property_of {
        # ランダムな表示名を生成
        display_name = "メンバー_" + Rantly { sized(range(1, 15)) { string(:alpha) } }
        # ランダムな Discord ID
        discord_id = "discord_prop_" + Rantly { sized(range(5, 15)) { string(:alnum) } }
        # ランダムな role（core または sub）
        role = choose("core", "sub")
        # 参加可否の数（1〜5件）
        avail_count = range(1, 5)
        # 各参加可否の status
        statuses = Array.new(avail_count) { choose(1, 0, -1) }
        [display_name, discord_id, role, avail_count, statuses]
      }.check(100) do |display_name, discord_id, role, avail_count, statuses|
        # テスト対象ユーザーを作成
        target_user = create(:user,
          display_name: display_name,
          discord_user_id: discord_id,
          discord_screen_name: "screen_#{discord_id}",
          google_account_id: "google_#{discord_id}@example.com",
          google_oauth_token: "token_#{discord_id}",
          auth_locked: true
        )
        create(:membership, role: role, user: target_user, group: group)

        # 参加可否データを作成
        avail_count.times do |i|
          date = future_date(i + 1)
          comment = statuses[i] != 1 ? "コメント#{i}" : nil
          create(:availability,
            user: target_user,
            group: group,
            date: date,
            status: statuses[i],
            comment: comment
          )
        end

        # セッションとカレンダーキャッシュも作成
        create(:session, user: target_user)
        create(:calendar_cache, user: target_user, group: group, date: future_date(1))

        original_avail_count = Availability.where(user: target_user, group: group).count

        # 退会処理を実行
        result = MemberAnonymizer.new(target_user, group).call
        expect(result[:success]).to be(true),
          "退会処理が失敗: display_name=#{display_name}, error=#{result[:error]}"

        target_user.reload

        # Property 17 検証: anonymized=true
        expect(target_user.anonymized).to be(true),
          "anonymized が true でない: display_name=#{display_name}"

        # Property 17 検証: display_name が匿名化形式
        expect(target_user.display_name).to match(/\A退会済みメンバー\d+\z/),
          "display_name が匿名化形式でない: got=#{target_user.display_name.inspect}"

        # Property 17 検証: google_oauth_token が null
        expect(target_user.google_oauth_token).to be_nil,
          "google_oauth_token が null でない"

        # Property 17 検証: google_account_id が null
        expect(target_user.google_account_id).to be_nil,
          "google_account_id が null でない"

        # Property 17 検証: discord_user_id が null（単一グループの場合）
        expect(target_user.discord_user_id).to be_nil,
          "discord_user_id が null でない"

        # Property 17 検証: availabilities レコードが保持されている
        remaining_avails = Availability.where(user: target_user, group: group).count
        expect(remaining_avails).to eq(original_avail_count),
          "availabilities が削除された: expected=#{original_avail_count}, got=#{remaining_avails}"

        # Property 17 検証: calendar_caches が削除されている
        expect(CalendarCache.where(user: target_user, group: group).count).to eq(0),
          "calendar_caches が削除されていない"

        # Property 17 検証: セッションが無効化されている
        expect(Session.where(user: target_user).count).to eq(0),
          "セッションが無効化されていない"

        # Property 17 検証: auth_locked が false
        expect(target_user.auth_locked).to be(false),
          "auth_locked が false でない"
      end
    end
  end

  describe "可視性制御: 一般メンバーからの非表示" do
    it "任意の退会メンバーのデータが一般メンバーの API レスポンスに含まれない" do
      property_of {
        # ランダムな参加可否の数（1〜3件）
        avail_count = range(1, 3)
        statuses = Array.new(avail_count) { choose(1, 0, -1) }
        # 日付オフセットの開始位置（各イテレーションで重複しないように）
        date_base = range(1, 50)
        [avail_count, statuses, date_base]
      }.check(100) do |avail_count, statuses, date_base|
        # 退会対象ユーザーを作成
        target_user = create(:user, :with_discord, :with_google)
        create(:membership, user: target_user, group: group)

        # 参加可否データを作成
        dates = []
        avail_count.times do |i|
          date = future_date(date_base + i)
          dates << date
          comment = statuses[i] != 1 ? "非表示コメント#{i}" : nil
          create(:availability,
            user: target_user,
            group: group,
            date: date,
            status: statuses[i],
            comment: comment
          )
        end

        # 退会処理を実行
        MemberAnonymizer.new(target_user, group).call
        target_user.reload

        # 一般メンバーとして API にアクセス（認証なし）
        month_str = dates.first.strftime("%Y-%m")
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "API リクエストが失敗: #{response.body}"

        json = response.parsed_body

        # メンバー一覧に退会メンバーが含まれない
        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).not_to include(target_user.id),
          "一般メンバーのレスポンスに退会メンバーが含まれている: user_id=#{target_user.id}"

        # 参加可否データに退会メンバーのデータが含まれない
        dates.each do |date|
          date_key = date.iso8601
          date_data = json.dig("availabilities", date_key) || {}
          expect(date_data.keys).not_to include(target_user.id.to_s),
            "一般メンバーのレスポンスに退会メンバーの参加可否が含まれている: " \
            "date=#{date_key}, user_id=#{target_user.id}"
        end
      end
    end

    it "X-User-Id ヘッダーで一般メンバーとしてアクセスしても退会メンバーが非表示" do
      property_of {
        avail_count = range(1, 3)
        statuses = Array.new(avail_count) { choose(1, 0, -1) }
        date_base = range(1, 50)
        [avail_count, statuses, date_base]
      }.check(100) do |avail_count, statuses, date_base|
        target_user = create(:user, :with_discord, :with_google)
        create(:membership, user: target_user, group: group)

        dates = []
        avail_count.times do |i|
          date = future_date(date_base + i)
          dates << date
          comment = statuses[i] != 1 ? "非表示コメント#{i}" : nil
          create(:availability,
            user: target_user,
            group: group,
            date: date,
            status: statuses[i],
            comment: comment
          )
        end

        MemberAnonymizer.new(target_user, group).call

        # X-User-Id ヘッダーで一般メンバーとしてアクセス
        month_str = dates.first.strftime("%Y-%m")
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str },
            headers: { "X-User-Id" => active_member.id.to_s }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).not_to include(target_user.id),
          "X-User-Id アクセスで退会メンバーが表示されている: user_id=#{target_user.id}"
      end
    end
  end

  describe "可視性制御: Owner からの閲覧可能" do
    it "任意の退会メンバーのデータが Owner の API レスポンスに含まれる" do
      property_of {
        avail_count = range(1, 3)
        statuses = Array.new(avail_count) { choose(1, 0, -1) }
        # 日付オフセットを月内に収める（同一月内で全日付が収まるように）
        date_base = range(1, 25)
        [avail_count, statuses, date_base]
      }.check(100) do |avail_count, statuses, date_base|
        target_user = create(:user, :with_discord, :with_google)
        create(:membership, user: target_user, group: group)

        # 全日付が同一月内に収まるように基準日を計算
        base_date = future_date(date_base)
        dates = []
        avail_count.times do |i|
          # 同一月内に収まるように日付を生成
          date = base_date.beginning_of_month + (base_date.day - 1 + i).days
          # 月末を超えないようにクランプ
          date = [date, base_date.end_of_month].min
          dates << date
          comment = statuses[i] != 1 ? "Ownerから見えるコメント#{i}" : nil
          Availability.find_or_initialize_by(
            user: target_user, group: group, date: date
          ).update!(status: statuses[i], comment: comment, auto_synced: false)
        end
        dates.uniq!

        # 退会前の参加可否データを記録
        original_avails = dates.map do |date|
          avail = Availability.find_by(user: target_user, group: group, date: date)
          { date: date, status: avail.status }
        end

        MemberAnonymizer.new(target_user, group).call
        target_user.reload

        # Owner として Cookie 認証でアクセス
        set_session_cookie(owner_session)
        month_str = base_date.strftime("%Y-%m")
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "Owner の API リクエストが失敗: #{response.body}"

        json = response.parsed_body

        # メンバー一覧に退会メンバーが含まれる
        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).to include(target_user.id),
          "Owner のレスポンスに退会メンバーが含まれていない: user_id=#{target_user.id}"

        # 退会メンバーの表示情報が正しい
        withdrawn_member = json["members"].find { |m| m["id"] == target_user.id }
        expect(withdrawn_member["display_name"]).to match(/\A退会済みメンバー\d+\z/),
          "退会メンバーの display_name が匿名化形式でない: " \
          "got=#{withdrawn_member['display_name'].inspect}"
        expect(withdrawn_member["role"]).to eq("withdrawn"),
          "退会メンバーの role が 'withdrawn' でない: got=#{withdrawn_member['role'].inspect}"
        expect(withdrawn_member["anonymized"]).to be(true),
          "退会メンバーの anonymized が true でない"
        expect(withdrawn_member["discord_screen_name"]).to be_nil,
          "退会メンバーの discord_screen_name が nil でない"

        # 参加可否データが保持されている
        original_avails.each do |avail_data|
          date_key = avail_data[:date].iso8601
          user_key = target_user.id.to_s
          avail = json.dig("availabilities", date_key, user_key)

          expect(avail).to be_present,
            "Owner のレスポンスに退会メンバーの参加可否が含まれていない: " \
            "date=#{date_key}, user_id=#{target_user.id}"
          expect(avail["status"]).to eq(avail_data[:status]),
            "退会メンバーの status が不一致: date=#{date_key}, " \
            "expected=#{avail_data[:status]}, got=#{avail['status']}"
        end
      end
    end
  end

  describe "複数グループ所属時の退会処理" do
    it "他グループに所属している場合、discord_user_id が保持される" do
      property_of {
        role = choose("core", "sub")
        avail_count = range(1, 3)
        statuses = Array.new(avail_count) { choose(1, 0, -1) }
        date_base = range(1, 50)
        [role, avail_count, statuses, date_base]
      }.check(100) do |role, avail_count, statuses, date_base|
        # 各イテレーションで独立した other_group を作成
        other_owner = create(:user, :with_discord)
        other_group = create(:group, :with_times, owner: other_owner, name: "他グループ")
        Membership.create!(role: "owner", user: other_owner, group: other_group)

        target_user = create(:user, :with_discord, :with_google)
        Membership.create!(role: role, user: target_user, group: group)
        Membership.create!(role: "sub", user: target_user, group: other_group)

        avail_count.times do |i|
          date = future_date(date_base + i)
          create(:availability,
            user: target_user,
            group: group,
            date: date,
            status: statuses[i]
          )
        end

        original_discord_id = target_user.discord_user_id
        original_avail_count = Availability.where(user: target_user, group: group).count

        result = MemberAnonymizer.new(target_user, group).call
        expect(result[:success]).to be(true),
          "退会処理が失敗: error=#{result[:error]}"

        target_user.reload

        # 匿名化は実行される
        expect(target_user.anonymized).to be(true)
        expect(target_user.display_name).to match(/\A退会済みメンバー\d+\z/)

        # Google 関連は削除される
        expect(target_user.google_oauth_token).to be_nil
        expect(target_user.google_account_id).to be_nil

        # 他グループに所属しているため discord_user_id は保持される
        expect(target_user.discord_user_id).to eq(original_discord_id),
          "他グループ所属時に discord_user_id が削除された: " \
          "expected=#{original_discord_id.inspect}, got=#{target_user.discord_user_id.inspect}"

        # availabilities は保持される
        remaining = Availability.where(user: target_user, group: group).count
        expect(remaining).to eq(original_avail_count),
          "availabilities が削除された: expected=#{original_avail_count}, got=#{remaining}"

        # 他グループのメンバーシップは保持される
        expect(Membership.where(user: target_user, group: other_group).count).to eq(1),
          "他グループのメンバーシップが削除された"

        # 対象グループのメンバーシップは削除される
        expect(Membership.where(user: target_user, group: group).count).to eq(0),
          "対象グループのメンバーシップが削除されていない"
      end
    end
  end
end
