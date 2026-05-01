# frozen_string_literal: true

require "rails_helper"
require "net/http"

RSpec.describe FreebusySyncService, type: :service do
  let!(:owner) { create(:user) }
  let!(:group) { create(:group, owner: owner, timezone: "Asia/Tokyo") }
  let(:date_range) { Date.new(2026, 5, 1)..Date.new(2026, 5, 7) }

  # Google 連携済みユーザーを作成するヘルパー
  # access_token の有効期限を未来に設定
  def create_connected_user(token_overrides = {})
    token_data = {
      "access_token" => "test_access_token",
      "refresh_token" => "test_refresh_token",
      "expires_at" => (Time.current + 1.hour).to_i
    }.merge(token_overrides)

    user = create(:user, :with_google, google_oauth_token: token_data.to_json)
    create(:membership, user: user, group: group, role: "core")
    user
  end

  # FreeBusy API のモックレスポンスを生成するヘルパー
  def freebusy_response_body(busy_periods = [])
    {
      "kind" => "calendar#freeBusy",
      "calendars" => {
        "primary" => {
          "busy" => busy_periods.map do |period|
            {
              "start" => period[:start].iso8601,
              "end" => period[:end].iso8601
            }
          end
        }
      }
    }.to_json
  end

  # Net::HTTP のモックを設定するヘルパー
  def stub_freebusy_api(response_body, status: "200")
    http_mock = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http_mock)
    allow(http_mock).to receive(:use_ssl=)

    response = instance_double(Net::HTTPSuccess, body: response_body, code: status)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(status == "200")
    allow(http_mock).to receive(:request).and_return(response)

    http_mock
  end

  describe "#call" do
    context "Google 連携済みメンバーがいない場合" do
      before do
        # 連携なしメンバーを追加
        user = create(:user)
        create(:membership, user: user, group: group, role: "core")
      end

      it "空の結果を返す" do
        service = described_class.new(group, date_range)
        result = service.call

        expect(result).to eq({ synced_users: 0, cached_dates: 0 })
      end
    end

    context "Google 連携済みメンバーがいる場合" do
      let!(:connected_user) { create_connected_user }

      before do
        busy_periods = [
          { start: Time.new(2026, 5, 2, 10, 0, 0), end: Time.new(2026, 5, 2, 12, 0, 0) },
          { start: Time.new(2026, 5, 5, 14, 0, 0), end: Time.new(2026, 5, 5, 16, 0, 0) }
        ]
        stub_freebusy_api(freebusy_response_body(busy_periods))
      end

      it "calendar_caches にキャッシュを保存する" do
        service = described_class.new(group, date_range)

        expect {
          service.call
        }.to change(CalendarCache, :count).by(7) # 7日分

        # 予定がある日
        cache_may2 = CalendarCache.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 2))
        expect(cache_may2.has_event).to be true

        cache_may5 = CalendarCache.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 5))
        expect(cache_may5.has_event).to be true

        # 予定がない日
        cache_may1 = CalendarCache.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 1))
        expect(cache_may1.has_event).to be false
      end

      it "has_event=true の日の Availability を自動的に × に設定する" do
        service = described_class.new(group, date_range)
        service.call

        avail_may2 = Availability.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 2))
        expect(avail_may2.status).to eq(-1)
        expect(avail_may2.auto_synced).to be true

        avail_may5 = Availability.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 5))
        expect(avail_may5.status).to eq(-1)
        expect(avail_may5.auto_synced).to be true
      end

      it "has_event=false の日は Availability を作成しない" do
        service = described_class.new(group, date_range)
        service.call

        avail_may1 = Availability.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 1))
        expect(avail_may1).to be_nil
      end

      it "同期結果を返す" do
        service = described_class.new(group, date_range)
        result = service.call

        expect(result[:synced_users]).to eq(1)
        expect(result[:cached_dates]).to eq(7)
      end
    end

    context "手動変更済みの Availability がある場合" do
      let!(:connected_user) { create_connected_user }

      before do
        # 手動で ○ に設定済み（auto_synced=false）
        create(:availability,
          user: connected_user,
          group: group,
          date: Date.new(2026, 5, 2),
          status: 1,
          auto_synced: false
        )

        busy_periods = [
          { start: Time.new(2026, 5, 2, 10, 0, 0), end: Time.new(2026, 5, 2, 12, 0, 0) }
        ]
        stub_freebusy_api(freebusy_response_body(busy_periods))
      end

      it "手動変更済みの Availability を上書きしない" do
        service = described_class.new(group, date_range)
        service.call

        avail = Availability.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 2))
        expect(avail.status).to eq(1) # ○ のまま
        expect(avail.auto_synced).to be false
      end
    end

    context "auto_synced=true の × が既にある場合" do
      let!(:connected_user) { create_connected_user }

      before do
        # 以前の同期で自動設定された ×
        create(:availability,
          user: connected_user,
          group: group,
          date: Date.new(2026, 5, 3),
          status: -1,
          auto_synced: true
        )

        # 今回の同期では 5/3 に予定がない
        busy_periods = []
        stub_freebusy_api(freebusy_response_body(busy_periods))
      end

      it "予定がなくなった日の auto_synced × をクリアする" do
        service = described_class.new(group, date_range)
        service.call

        avail = Availability.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 3))
        expect(avail.status).to be_nil
        expect(avail.auto_synced).to be false
      end
    end

    context "キャッシュが有効な場合" do
      let!(:connected_user) { create_connected_user }

      before do
        # 全日付分の新鮮なキャッシュを作成
        date_range.each do |date|
          create(:calendar_cache, :fresh,
            user: connected_user,
            group: group,
            date: date,
            has_event: false
          )
        end
      end

      it "API を呼び出さずスキップする" do
        # Net::HTTP が呼ばれないことを確認
        expect(Net::HTTP).not_to receive(:new)

        service = described_class.new(group, date_range)
        service.call
      end

      it "force=true の場合はキャッシュを無視して再取得する" do
        stub_freebusy_api(freebusy_response_body([]))

        service = described_class.new(group, date_range, force: true)
        result = service.call

        expect(result[:cached_dates]).to eq(7)
      end
    end

    context "キャッシュが古い場合" do
      let!(:connected_user) { create_connected_user }

      before do
        # 古いキャッシュを作成
        date_range.each do |date|
          create(:calendar_cache, :stale,
            user: connected_user,
            group: group,
            date: date,
            has_event: false
          )
        end

        stub_freebusy_api(freebusy_response_body([]))
      end

      it "API を呼び出して再取得する" do
        service = described_class.new(group, date_range)
        result = service.call

        expect(result[:cached_dates]).to eq(7)
      end
    end

    context "トークンが期限切れの場合" do
      let!(:connected_user) do
        create_connected_user("expires_at" => (Time.current - 1.hour).to_i)
      end

      it "リフレッシュトークンで再取得を試みる" do
        # トークンリフレッシュのモック
        refresh_response = instance_double(
          Net::HTTPSuccess,
          body: {
            "access_token" => "new_access_token",
            "expires_in" => 3600
          }.to_json
        )
        allow(refresh_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:post_form).and_return(refresh_response)

        # FreeBusy API のモック
        stub_freebusy_api(freebusy_response_body([]))

        service = described_class.new(group, date_range)
        service.call

        # トークンが更新されていることを確認
        connected_user.reload
        token_data = JSON.parse(connected_user.google_oauth_token)
        expect(token_data["access_token"]).to eq("new_access_token")
      end
    end

    context "トークンリフレッシュに失敗した場合" do
      let!(:connected_user) do
        create_connected_user(
          "expires_at" => (Time.current - 1.hour).to_i,
          "refresh_token" => nil
        )
      end

      it "エラーをログに記録しスキップする" do
        expect(Rails.logger).to receive(:warn).with(/トークンリフレッシュに失敗/)

        service = described_class.new(group, date_range)
        result = service.call

        # エラーが発生してもクラッシュしない
        expect(result[:synced_users]).to eq(1)
      end
    end

    context "FreeBusy API がエラーを返した場合" do
      let!(:connected_user) { create_connected_user }

      before do
        stub_freebusy_api('{"error": "rate_limit_exceeded"}', status: "429")
      end

      it "エラーをログに記録しスキップする" do
        expect(Rails.logger).to receive(:warn).with(/API 呼び出しに失敗/)

        service = described_class.new(group, date_range)
        result = service.call

        # エラーが発生してもクラッシュしない
        expect(result[:synced_users]).to eq(1)
      end
    end

    context "複数日にまたがる予定がある場合" do
      let!(:connected_user) { create_connected_user }

      before do
        busy_periods = [
          # 5/3 10:00 〜 5/5 18:00（3日間にまたがる）
          { start: Time.new(2026, 5, 3, 10, 0, 0), end: Time.new(2026, 5, 5, 18, 0, 0) }
        ]
        stub_freebusy_api(freebusy_response_body(busy_periods))
      end

      it "全ての日付に has_event=true を設定する" do
        service = described_class.new(group, date_range)
        service.call

        [Date.new(2026, 5, 3), Date.new(2026, 5, 4), Date.new(2026, 5, 5)].each do |date|
          cache = CalendarCache.find_by(user: connected_user, group: group, date: date)
          expect(cache.has_event).to be true
        end
      end
    end

    context "has_event のみを保存する（プライバシー制約）" do
      let!(:connected_user) { create_connected_user }

      before do
        busy_periods = [
          { start: Time.new(2026, 5, 2, 10, 0, 0), end: Time.new(2026, 5, 2, 12, 0, 0) }
        ]
        stub_freebusy_api(freebusy_response_body(busy_periods))
      end

      it "calendar_caches に has_event（boolean）のみが保存される" do
        service = described_class.new(group, date_range)
        service.call

        # calendar_caches テーブルのカラムを確認
        columns = CalendarCache.column_names
        # has_event, fetched_at, user_id, group_id, date, id のみ
        # タイトル、詳細、参加者等のカラムは存在しない
        expect(columns).not_to include("title")
        expect(columns).not_to include("description")
        expect(columns).not_to include("attendees")
        expect(columns).not_to include("event_title")
        expect(columns).not_to include("event_details")

        # 保存されたデータが boolean のみであることを確認
        cache = CalendarCache.find_by(user: connected_user, group: group, date: Date.new(2026, 5, 2))
        expect(cache.has_event).to be_in([true, false])
      end
    end
  end

  describe "#call — 複数メンバーの同期" do
    let!(:user1) { create_connected_user }
    let!(:user2) { create_connected_user }

    before do
      busy_periods = [
        { start: Time.new(2026, 5, 1, 10, 0, 0), end: Time.new(2026, 5, 1, 12, 0, 0) }
      ]
      stub_freebusy_api(freebusy_response_body(busy_periods))
    end

    it "全連携メンバー分のキャッシュを作成する" do
      service = described_class.new(group, date_range)
      service.call

      expect(CalendarCache.where(group: group).count).to eq(14) # 2ユーザー × 7日
    end

    it "全連携メンバー分の Availability を自動設定する" do
      service = described_class.new(group, date_range)
      service.call

      [user1, user2].each do |user|
        avail = Availability.find_by(user: user, group: group, date: Date.new(2026, 5, 1))
        expect(avail.status).to eq(-1)
        expect(avail.auto_synced).to be true
      end
    end
  end

  describe "キャッシュ有効期限判定" do
    it "fetched_at から15分以上経過でキャッシュ無効" do
      cache = build(:calendar_cache, fetched_at: 16.minutes.ago)
      expect(cache.stale?).to be true
    end

    it "fetched_at から15分未満でキャッシュ有効" do
      cache = build(:calendar_cache, fetched_at: 14.minutes.ago)
      expect(cache.stale?).to be false
    end

    it "fetched_at が nil の場合はキャッシュ無効" do
      cache = build(:calendar_cache, fetched_at: nil)
      expect(cache.stale?).to be true
    end
  end
end
