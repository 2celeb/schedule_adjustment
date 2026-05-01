# frozen_string_literal: true

require 'rails_helper'
require 'rantly'
require 'rantly/property'

# Feature: schedule-management-tool, Property 7: 過去日付の権限制御
#
# 任意の過去日付について、一般メンバーの変更は拒否され、
# Owner の変更は許可されることを検証する。
#
# Validates: 要件 3.7, 3.8
RSpec.describe "Property 7: 過去日付の権限制御", type: :request do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user, display_name: "オーナー") }
  let!(:group) do
    create(:group, :with_times,
           owner: owner,
           name: "過去日付テストグループ",
           locale: "ja")
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }
  let!(:owner_session) { create(:session, user: owner) }

  let!(:regular_member) { create(:user, display_name: "一般メンバー") }
  let!(:regular_membership) { create(:membership, user: regular_member, group: group) }

  let!(:core_member) { create(:user, display_name: "コアメンバー") }
  let!(:core_membership) { create(:membership, :core, user: core_member, group: group) }

  # 過去日付を生成する（1〜365日前）
  def past_date(days_ago)
    Date.current - days_ago.days
  end

  describe "一般メンバーによる過去日付の変更拒否" do
    it "任意の過去日付と有効な status について、一般メンバー（Sub）の変更は拒否される" do
      property_of {
        days_ago = range(1, 365)
        status = choose(1, 0, -1)
        comment = if status == 1
                    nil
                  else
                    Rantly { sized(range(0, 30)) { string(:alpha) } }
                  end
        [days_ago, status, comment]
      }.check(100) do |days_ago, status, comment|
        date = past_date(days_ago)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: regular_member.id,
              availabilities: [
                { date: date.iso8601, status: status, comment: comment }
              ]
            },
            headers: { "X-User-Id" => regular_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity),
          "一般メンバーの過去日付変更が拒否されなかった: " \
          "date=#{date.iso8601}, days_ago=#{days_ago}, status=#{status}, " \
          "response_status=#{response.status}, body=#{response.body}"

        json = response.parsed_body
        expect(json["error"]["details"]).to be_present,
          "エラー詳細が返されなかった: date=#{date.iso8601}"
        expect(json["error"]["details"][0]["message"]).to include("過去の日付"),
          "エラーメッセージに「過去の日付」が含まれていない: " \
          "message=#{json['error']['details'][0]['message']}"

        # DB にレコードが作成されていないことを確認
        db_record = Availability.find_by(
          user: regular_member, group: group, date: date
        )
        expect(db_record).to be_nil,
          "拒否されたはずの過去日付に DB レコードが存在する: date=#{date.iso8601}"
      end
    end

    it "任意の過去日付と有効な status について、一般メンバー（Core）の変更も拒否される" do
      property_of {
        days_ago = range(1, 365)
        status = choose(1, 0, -1)
        [days_ago, status]
      }.check(100) do |days_ago, status|
        date = past_date(days_ago)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: core_member.id,
              availabilities: [
                { date: date.iso8601, status: status, comment: nil }
              ]
            },
            headers: { "X-User-Id" => core_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity),
          "Core メンバーの過去日付変更が拒否されなかった: " \
          "date=#{date.iso8601}, days_ago=#{days_ago}, status=#{status}"

        json = response.parsed_body
        expect(json["error"]["details"][0]["message"]).to include("過去の日付"),
          "エラーメッセージに「過去の日付」が含まれていない"
      end
    end
  end

  describe "Owner による過去日付の変更許可" do
    it "任意の過去日付と有効な status について、Owner の変更は許可される" do
      property_of {
        days_ago = range(1, 365)
        status = choose(1, 0, -1)
        comment = if status == 1
                    nil
                  else
                    Rantly { sized(range(0, 30)) { string(:alpha) } }
                  end
        [days_ago, status, comment]
      }.check(100) do |days_ago, status, comment|
        date = past_date(days_ago)

        # Owner は Cookie 認証が必要
        set_session_cookie(owner_session)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: owner.id,
              availabilities: [
                { date: date.iso8601, status: status, comment: comment }
              ]
            },
            as: :json

        expect(response).to have_http_status(:ok),
          "Owner の過去日付変更が拒否された: " \
          "date=#{date.iso8601}, days_ago=#{days_ago}, status=#{status}, " \
          "response_status=#{response.status}, body=#{response.body}"

        json = response.parsed_body
        updated = json["updated"]
        expect(updated).to be_present,
          "更新結果が返されなかった: date=#{date.iso8601}"
        expect(updated[0]["date"]).to eq(date.iso8601),
          "更新された日付が一致しない: expected=#{date.iso8601}, got=#{updated[0]['date']}"
        expect(updated[0]["status"]).to eq(status),
          "更新された status が一致しない: expected=#{status}, got=#{updated[0]['status']}"

        expected_comment = (status == -1 || status == 0) ? comment : nil
        expect(updated[0]["comment"]).to eq(expected_comment),
          "更新された comment が一致しない: expected=#{expected_comment.inspect}, got=#{updated[0]['comment'].inspect}"

        # DB の値も直接確認する
        db_record = Availability.find_by(user: owner, group: group, date: date)
        expect(db_record).to be_present,
          "Owner の過去日付変更が DB に保存されていない: date=#{date.iso8601}"
        expect(db_record.status).to eq(status),
          "DB の status が一致しない: expected=#{status}, got=#{db_record.status}"
        expect(db_record.comment).to eq(expected_comment),
          "DB の comment が一致しない: expected=#{expected_comment.inspect}, got=#{db_record.comment.inspect}"
      end
    end
  end

  describe "過去日付と未来日付の境界" do
    it "任意の status について、当日の変更は一般メンバーでも許可される" do
      property_of {
        status = choose(1, 0, -1)
        comment = if status == 1
                    nil
                  else
                    Rantly { sized(range(0, 30)) { string(:alpha) } }
                  end
        [status, comment]
      }.check(100) do |status, comment|
        date = Date.current

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: regular_member.id,
              availabilities: [
                { date: date.iso8601, status: status, comment: comment }
              ]
            },
            headers: { "X-User-Id" => regular_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok),
          "一般メンバーの当日変更が拒否された: " \
          "date=#{date.iso8601}, status=#{status}, " \
          "response_status=#{response.status}, body=#{response.body}"

        json = response.parsed_body
        expect(json["updated"][0]["status"]).to eq(status),
          "当日の status が一致しない: expected=#{status}, got=#{json['updated'][0]['status']}"
      end
    end

    it "任意の未来日付と status について、一般メンバーの変更は許可される" do
      property_of {
        days_ahead = range(1, 60)
        status = choose(1, 0, -1)
        [days_ahead, status]
      }.check(100) do |days_ahead, status|
        date = Date.current + days_ahead.days

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: regular_member.id,
              availabilities: [
                { date: date.iso8601, status: status, comment: nil }
              ]
            },
            headers: { "X-User-Id" => regular_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok),
          "一般メンバーの未来日付変更が拒否された: " \
          "date=#{date.iso8601}, days_ahead=#{days_ahead}, status=#{status}"
      end
    end
  end

  describe "AvailabilityPolicy の直接検証" do
    it "任意の過去日付について、一般メンバーの update? は false を返す" do
      property_of {
        days_ago = range(1, 365)
        guard days_ago > 0
        days_ago
      }.check(100) do |days_ago|
        date = past_date(days_ago)
        policy = AvailabilityPolicy.new(regular_member, group)

        expect(policy.update?(date: date)).to be(false),
          "一般メンバーの過去日付で update? が true を返した: " \
          "date=#{date.iso8601}, days_ago=#{days_ago}"
      end
    end

    it "任意の過去日付について、Owner の update? は true を返す" do
      property_of {
        days_ago = range(1, 365)
        guard days_ago > 0
        days_ago
      }.check(100) do |days_ago|
        date = past_date(days_ago)
        policy = AvailabilityPolicy.new(owner, group)

        expect(policy.update?(date: date)).to be(true),
          "Owner の過去日付で update? が false を返した: " \
          "date=#{date.iso8601}, days_ago=#{days_ago}"
      end
    end

    it "任意の当日または未来日付について、一般メンバーの update? は true を返す" do
      property_of {
        days_ahead = range(0, 365)
        days_ahead
      }.check(100) do |days_ahead|
        date = Date.current + days_ahead.days
        policy = AvailabilityPolicy.new(regular_member, group)

        expect(policy.update?(date: date)).to be(true),
          "一般メンバーの当日/未来日付で update? が false を返した: " \
          "date=#{date.iso8601}, days_ahead=#{days_ahead}"
      end
    end
  end
end
