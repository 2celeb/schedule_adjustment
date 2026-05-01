# frozen_string_literal: true

require "rails_helper"
require "rantly"
require "rantly/property"

# Feature: schedule-management-tool, Property 13: Event_Day デフォルト時間適用
#
# 任意の Event_Day について、start_time/end_time が null の場合に
# グループの default_start_time / default_end_time が使用されることを検証する。
#
# Validates: 要件 5.9
RSpec.describe "Property 13: Event_Day デフォルト時間適用", type: :request do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  let!(:owner) { create(:user, display_name: "オーナー") }
  let!(:group) do
    create(:group,
           owner: owner,
           default_start_time: "19:00",
           default_end_time: "22:00",
           locale: "ja")
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

  # 各イテレーションでテストデータをクリーンアップする
  def cleanup_event_days!
    EventDay.where(group: group).delete_all
  end

  # グループのデフォルト時間を更新する
  def update_group_defaults!(start_time, end_time)
    group.update!(default_start_time: start_time, default_end_time: end_time)
  end

  describe "EventDays API でのデフォルト時間適用" do
    it "start_time/end_time が null の EventDay はグループのデフォルト値で返される" do
      property_of {
        # グループのデフォルト時間をランダムに生成
        default_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        default_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        # 日付のオフセット（1〜60日先）
        date_offset = range(1, 60)
        [default_start, default_end, date_offset]
      }.check(100) do |default_start, default_end, date_offset|
        cleanup_event_days!
        update_group_defaults!(default_start, default_end)

        date = Date.current + date_offset.days

        # start_time/end_time が null の EventDay を作成
        event_day = create(:event_day,
                           group: group,
                           date: date,
                           start_time: nil,
                           end_time: nil)

        # EventDays API で取得
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.id}/event_days", params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "GET event_days が失敗: response=#{response.body}"

        json = response.parsed_body
        ed_data = json["event_days"].find { |ed| ed["id"] == event_day.id }

        expect(ed_data).to be_present,
          "レスポンスに EventDay が存在しない: id=#{event_day.id}"

        # null の場合はグループのデフォルト値が使用される
        expect(ed_data["start_time"]).to eq(default_start),
          "start_time がグループデフォルトと不一致: " \
          "expected=#{default_start}, got=#{ed_data['start_time']}"
        expect(ed_data["end_time"]).to eq(default_end),
          "end_time がグループデフォルトと不一致: " \
          "expected=#{default_end}, got=#{ed_data['end_time']}"

        # custom_time は false であること（デフォルト値を使用しているため）
        expect(ed_data["custom_time"]).to eq(false),
          "start_time/end_time が null なのに custom_time が true"
      end
    end

    it "start_time/end_time が設定済みの EventDay はその値がそのまま返される" do
      property_of {
        # グループのデフォルト時間
        default_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        default_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        # EventDay 固有の時間
        custom_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        custom_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        date_offset = range(1, 60)
        [default_start, default_end, custom_start, custom_end, date_offset]
      }.check(100) do |default_start, default_end, custom_start, custom_end, date_offset|
        cleanup_event_days!
        update_group_defaults!(default_start, default_end)

        date = Date.current + date_offset.days

        # start_time/end_time を明示的に設定した EventDay を作成
        event_day = create(:event_day,
                           group: group,
                           date: date,
                           start_time: custom_start,
                           end_time: custom_end)

        # EventDays API で取得
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.id}/event_days", params: { month: month_str }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        ed_data = json["event_days"].find { |ed| ed["id"] == event_day.id }

        expect(ed_data).to be_present

        # 設定済みの値がそのまま返される
        expect(ed_data["start_time"]).to eq(custom_start),
          "start_time がカスタム値と不一致: " \
          "expected=#{custom_start}, got=#{ed_data['start_time']}"
        expect(ed_data["end_time"]).to eq(custom_end),
          "end_time がカスタム値と不一致: " \
          "expected=#{custom_end}, got=#{ed_data['end_time']}"

        # custom_time は true であること
        expect(ed_data["custom_time"]).to eq(true),
          "start_time/end_time が設定済みなのに custom_time が false"
      end
    end

    it "start_time のみ null の場合、start_time はデフォルト値、end_time はカスタム値が返される" do
      property_of {
        default_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        default_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        custom_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        date_offset = range(1, 60)
        [default_start, default_end, custom_end, date_offset]
      }.check(100) do |default_start, default_end, custom_end, date_offset|
        cleanup_event_days!
        update_group_defaults!(default_start, default_end)

        date = Date.current + date_offset.days

        # start_time のみ null
        event_day = create(:event_day,
                           group: group,
                           date: date,
                           start_time: nil,
                           end_time: custom_end)

        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.id}/event_days", params: { month: month_str }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        ed_data = json["event_days"].find { |ed| ed["id"] == event_day.id }

        expect(ed_data).to be_present

        # start_time はデフォルト値
        expect(ed_data["start_time"]).to eq(default_start),
          "start_time がデフォルトと不一致: expected=#{default_start}, got=#{ed_data['start_time']}"
        # end_time はカスタム値
        expect(ed_data["end_time"]).to eq(custom_end),
          "end_time がカスタム値と不一致: expected=#{custom_end}, got=#{ed_data['end_time']}"
        # end_time が設定されているので custom_time は true
        expect(ed_data["custom_time"]).to eq(true),
          "end_time が設定済みなのに custom_time が false"
      end
    end

    it "end_time のみ null の場合、end_time はデフォルト値、start_time はカスタム値が返される" do
      property_of {
        default_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        default_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        custom_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        date_offset = range(1, 60)
        [default_start, default_end, custom_start, date_offset]
      }.check(100) do |default_start, default_end, custom_start, date_offset|
        cleanup_event_days!
        update_group_defaults!(default_start, default_end)

        date = Date.current + date_offset.days

        # end_time のみ null
        event_day = create(:event_day,
                           group: group,
                           date: date,
                           start_time: custom_start,
                           end_time: nil)

        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.id}/event_days", params: { month: month_str }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        ed_data = json["event_days"].find { |ed| ed["id"] == event_day.id }

        expect(ed_data).to be_present

        # start_time はカスタム値
        expect(ed_data["start_time"]).to eq(custom_start),
          "start_time がカスタム値と不一致: expected=#{custom_start}, got=#{ed_data['start_time']}"
        # end_time はデフォルト値
        expect(ed_data["end_time"]).to eq(default_end),
          "end_time がデフォルトと不一致: expected=#{default_end}, got=#{ed_data['end_time']}"
        # start_time が設定されているので custom_time は true
        expect(ed_data["custom_time"]).to eq(true),
          "start_time が設定済みなのに custom_time が false"
      end
    end
  end

  describe "Availabilities API でのデフォルト時間適用" do
    it "参加可否取得 API の event_days でもデフォルト時間が適用される" do
      property_of {
        default_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        default_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        # null パターン: 0=両方null, 1=start_timeのみnull, 2=end_timeのみnull, 3=両方設定
        null_pattern = range(0, 3)
        custom_start = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        custom_end = Rantly { format("%02d:%02d", range(0, 23), choose(0, 15, 30, 45)) }
        date_offset = range(1, 28)
        [default_start, default_end, null_pattern, custom_start, custom_end, date_offset]
      }.check(100) do |default_start, default_end, null_pattern, custom_start, custom_end, date_offset|
        cleanup_event_days!
        update_group_defaults!(default_start, default_end)

        date = Date.current + date_offset.days

        # null_pattern に応じて start_time/end_time を設定
        ed_start = [0, 1].include?(null_pattern) ? nil : custom_start
        ed_end = [0, 2].include?(null_pattern) ? nil : custom_end

        create(:event_day,
               group: group,
               date: date,
               start_time: ed_start,
               end_time: ed_end)

        # Availabilities API で取得
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "GET availabilities が失敗: response=#{response.body}"

        json = response.parsed_body
        ed_data = json.dig("event_days", date.iso8601)

        expect(ed_data).to be_present,
          "Availabilities レスポンスに event_day が存在しない: date=#{date.iso8601}"

        # 期待される start_time / end_time
        expected_start = ed_start || default_start
        expected_end = ed_end || default_end

        expect(ed_data["start_time"]).to eq(expected_start),
          "Availabilities API の start_time が不一致: " \
          "null_pattern=#{null_pattern}, expected=#{expected_start}, got=#{ed_data['start_time']}"
        expect(ed_data["end_time"]).to eq(expected_end),
          "Availabilities API の end_time が不一致: " \
          "null_pattern=#{null_pattern}, expected=#{expected_end}, got=#{ed_data['end_time']}"

        # custom_time フラグの検証
        expected_custom = ed_start.present? || ed_end.present?
        expect(ed_data["custom_time"]).to eq(expected_custom),
          "Availabilities API の custom_time が不一致: " \
          "null_pattern=#{null_pattern}, expected=#{expected_custom}, got=#{ed_data['custom_time']}"
      end
    end
  end
end
