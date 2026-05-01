# frozen_string_literal: true

require "rails_helper"
require "net/http"

RSpec.describe CalendarWriteService, type: :service do
  let!(:owner) do
    create(:user, :with_google,
      google_calendar_scope: "calendar",
      google_oauth_token: {
        "access_token" => "owner_access_token",
        "refresh_token" => "owner_refresh_token",
        "expires_at" => (Time.current + 1.hour).to_i
      }.to_json
    )
  end
  let!(:group) do
    create(:group,
      owner: owner,
      name: "テストグループ",
      event_name: "テスト活動",
      timezone: "Asia/Tokyo",
      default_start_time: "19:00",
      default_end_time: "22:00"
    )
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }
  let!(:event_day) do
    create(:event_day, :confirmed, :with_times, group: group, date: Date.new(2026, 6, 15))
  end

  # Google Calendar API のモックヘルパー
  def stub_calendar_api_success(response_body = {})
    http_mock = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http_mock)
    allow(http_mock).to receive(:use_ssl=)

    response = instance_double(Net::HTTPSuccess,
      body: response_body.to_json,
      code: "200"
    )
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(http_mock).to receive(:request).and_return(response)

    http_mock
  end

  def stub_calendar_api_error(status_code = "403", error_body = '{"error": "forbidden"}')
    http_mock = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http_mock)
    allow(http_mock).to receive(:use_ssl=)

    response = instance_double(Net::HTTPResponse,
      body: error_body,
      code: status_code
    )
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    allow(http_mock).to receive(:request).and_return(response)

    http_mock
  end

  # 書き込み連携メンバーを作成するヘルパー
  def create_write_member(scope: "freebusy_events")
    token_data = {
      "access_token" => "member_access_token_#{SecureRandom.hex(4)}",
      "refresh_token" => "member_refresh_token",
      "expires_at" => (Time.current + 1.hour).to_i
    }
    user = create(:user, :with_google,
      google_calendar_scope: scope,
      google_oauth_token: token_data.to_json
    )
    create(:membership, :core, user: user, group: group)
    user
  end

  describe "#call" do
    context "Owner に calendar スコープがない場合" do
      before do
        owner.update!(google_calendar_scope: nil)
      end

      it "エラーを返し処理を中断する" do
        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:owner_event_created]).to be false
        expect(result[:errors]).to include("Owner に calendar スコープがありません")
      end
    end

    context "Owner の google_oauth_token が空の場合" do
      before do
        owner.update!(google_oauth_token: nil, google_calendar_scope: "calendar")
      end

      it "エラーを返し処理を中断する" do
        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:owner_event_created]).to be false
        expect(result[:errors]).to include("Owner に calendar スコープがありません")
      end
    end
  end

  describe "サブカレンダー作成" do
    context "サブカレンダーが未作成の場合" do
      it "Google Calendar API でサブカレンダーを作成する" do
        calendar_response = { "id" => "new_sub_calendar_id@group.calendar.google.com" }
        event_response = { "id" => "event_123" }

        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)

        # 1回目: サブカレンダー作成、2回目: イベント作成
        call_count = 0
        allow(http_mock).to receive(:request) do |req|
          call_count += 1
          body = call_count == 1 ? calendar_response.to_json : event_response.to_json
          response = instance_double(Net::HTTPSuccess, body: body, code: "200")
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          response
        end

        service = described_class.new(group, event_day)
        service.call

        group.reload
        expect(group.google_sub_calendar_id).to eq("new_sub_calendar_id@group.calendar.google.com")
      end

      it "サブカレンダー名が「[グループ名] イベント」形式である" do
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)

        captured_body = nil
        allow(http_mock).to receive(:request) do |req|
          captured_body ||= req.body
          body = { "id" => "cal_id@group.calendar.google.com" }.to_json
          response = instance_double(Net::HTTPSuccess, body: body, code: "200")
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          response
        end

        service = described_class.new(group, event_day)
        service.call

        parsed = JSON.parse(captured_body)
        expect(parsed["summary"]).to eq("テストグループ イベント")
        expect(parsed["timeZone"]).to eq("Asia/Tokyo")
      end
    end

    context "サブカレンダーが既に作成済みの場合" do
      before do
        group.update!(google_sub_calendar_id: "existing_calendar_id@group.calendar.google.com")
      end

      it "サブカレンダーを再作成しない" do
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)

        request_bodies = []
        allow(http_mock).to receive(:request) do |req|
          request_bodies << req.body
          body = { "id" => "event_123" }.to_json
          response = instance_double(Net::HTTPSuccess, body: body, code: "200")
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          response
        end

        service = described_class.new(group, event_day)
        service.call

        # イベント作成のリクエストのみ（サブカレンダー作成なし）
        expect(request_bodies.size).to eq(1)
        parsed = JSON.parse(request_bodies.first)
        expect(parsed).to have_key("summary")
        expect(parsed["summary"]).to eq("テスト活動")
      end
    end

    context "サブカレンダー作成 API がエラーを返した場合" do
      it "エラーをログに記録し処理を中断する" do
        stub_calendar_api_error

        expect(Rails.logger).to receive(:error).with(/サブカレンダー作成失敗/)

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:owner_event_created]).to be false
        expect(result[:errors].first).to match(/サブカレンダー作成失敗/)
      end
    end
  end

  describe "Owner のサブカレンダーへの予定作成" do
    before do
      group.update!(google_sub_calendar_id: "owner_sub_cal@group.calendar.google.com")
    end

    it "Owner のサブカレンダーに予定を作成する" do
      stub_calendar_api_success("id" => "event_123")

      service = described_class.new(group, event_day)
      result = service.call

      expect(result[:owner_event_created]).to be true
    end

    it "イベントのタイトルがグループの event_name である" do
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)

      captured_body = nil
      allow(http_mock).to receive(:request) do |req|
        captured_body = req.body
        response = instance_double(Net::HTTPSuccess, body: { "id" => "ev1" }.to_json, code: "200")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end

      service = described_class.new(group, event_day)
      service.call

      parsed = JSON.parse(captured_body)
      expect(parsed["summary"]).to eq("テスト活動")
    end

    it "event_name が空の場合はグループ名をタイトルにする" do
      group.update!(event_name: nil)

      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)

      captured_body = nil
      allow(http_mock).to receive(:request) do |req|
        captured_body = req.body
        response = instance_double(Net::HTTPSuccess, body: { "id" => "ev1" }.to_json, code: "200")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end

      service = described_class.new(group, event_day)
      service.call

      parsed = JSON.parse(captured_body)
      expect(parsed["summary"]).to eq("テストグループ")
    end

    it "イベントの説明にメンバー一覧が含まれる" do
      # 参加メンバー
      participating_user = create(:user, display_name: "参加太郎")
      create(:membership, :core, user: participating_user, group: group)
      create(:availability, user: participating_user, group: group, date: event_day.date, status: 1)

      # 不参加メンバー
      absent_user = create(:user, display_name: "不参加花子")
      create(:membership, user: absent_user, group: group)
      create(:availability, user: absent_user, group: group, date: event_day.date, status: -1)

      # 未定メンバー
      undecided_user = create(:user, display_name: "未定次郎")
      create(:membership, user: undecided_user, group: group)
      create(:availability, user: undecided_user, group: group, date: event_day.date, status: 0)

      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)

      captured_body = nil
      allow(http_mock).to receive(:request) do |req|
        captured_body = req.body
        response = instance_double(Net::HTTPSuccess, body: { "id" => "ev1" }.to_json, code: "200")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end

      service = described_class.new(group, event_day)
      service.call

      parsed = JSON.parse(captured_body)
      description = parsed["description"]

      expect(description).to include("【参加メンバー】")
      expect(description).to include("参加太郎")
      expect(description).to include("【不参加メンバー】")
      expect(description).to include("不参加花子")
      expect(description).to include("【未定・未入力】")
      expect(description).to include("未定次郎")
    end

    it "EventDay の時間を使用する" do
      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)

      captured_body = nil
      allow(http_mock).to receive(:request) do |req|
        captured_body = req.body
        response = instance_double(Net::HTTPSuccess, body: { "id" => "ev1" }.to_json, code: "200")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end

      service = described_class.new(group, event_day)
      service.call

      parsed = JSON.parse(captured_body)
      expect(parsed["start"]["timeZone"]).to eq("Asia/Tokyo")
      expect(parsed["end"]["timeZone"]).to eq("Asia/Tokyo")
      # EventDay の :with_times トレイトは 19:00-22:00
      expect(parsed["start"]["dateTime"]).to include("19:00")
      expect(parsed["end"]["dateTime"]).to include("22:00")
    end

    it "EventDay の時間が nil の場合はグループデフォルトを使用する" do
      event_day_no_time = create(:event_day, :confirmed, group: group, date: Date.new(2026, 6, 20))

      http_mock = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_mock)
      allow(http_mock).to receive(:use_ssl=)

      captured_body = nil
      allow(http_mock).to receive(:request) do |req|
        captured_body = req.body
        response = instance_double(Net::HTTPSuccess, body: { "id" => "ev1" }.to_json, code: "200")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end

      service = described_class.new(group, event_day_no_time)
      service.call

      parsed = JSON.parse(captured_body)
      # グループデフォルト: 19:00-22:00
      expect(parsed["start"]["dateTime"]).to include("19:00")
      expect(parsed["end"]["dateTime"]).to include("22:00")
    end

    context "Owner 予定作成 API がエラーを返した場合" do
      it "エラーをログに記録するが処理は続行する" do
        stub_calendar_api_error

        expect(Rails.logger).to receive(:error).with(/Owner 予定作成失敗/)

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:owner_event_created]).to be false
        expect(result[:errors]).to include(match(/Owner 予定作成失敗/))
      end
    end
  end

  describe "書き込み連携メンバーの個人カレンダーへの予定作成" do
    before do
      group.update!(google_sub_calendar_id: "owner_sub_cal@group.calendar.google.com")
    end

    context "書き込み連携メンバーがいる場合" do
      let!(:write_member) { create_write_member(scope: "freebusy_events") }

      it "メンバーの個人カレンダーに予定を作成する" do
        stub_calendar_api_success("id" => "event_123")

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:member_events_created]).to eq(1)
      end
    end

    context "calendar スコープのメンバーがいる場合" do
      let!(:calendar_member) { create_write_member(scope: "calendar") }

      it "メンバーの個人カレンダーに予定を作成する" do
        stub_calendar_api_success("id" => "event_123")

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:member_events_created]).to eq(1)
      end
    end

    context "freebusy スコープのみのメンバーがいる場合" do
      before do
        token_data = {
          "access_token" => "readonly_token",
          "refresh_token" => "readonly_refresh",
          "expires_at" => (Time.current + 1.hour).to_i
        }
        user = create(:user, :with_google,
          google_calendar_scope: "freebusy",
          google_oauth_token: token_data.to_json
        )
        create(:membership, :core, user: user, group: group)
      end

      it "書き込みスコープがないメンバーはスキップする" do
        stub_calendar_api_success("id" => "event_123")

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:member_events_created]).to eq(0)
      end
    end

    context "Google 未連携メンバーがいる場合" do
      before do
        user = create(:user)
        create(:membership, :core, user: user, group: group)
      end

      it "未連携メンバーはスキップする" do
        stub_calendar_api_success("id" => "event_123")

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:member_events_created]).to eq(0)
      end
    end

    context "メンバーの予定作成が失敗した場合" do
      let!(:write_member1) { create_write_member(scope: "freebusy_events") }
      let!(:write_member2) { create_write_member(scope: "freebusy_events") }

      it "失敗したメンバーをスキップし他のメンバーの処理を続行する" do
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)

        call_count = 0
        allow(http_mock).to receive(:request) do |_req|
          call_count += 1
          if call_count == 2
            # 2回目（最初のメンバー）は失敗
            response = instance_double(Net::HTTPResponse, body: '{"error": "forbidden"}', code: "403")
            allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
            response
          else
            # 1回目（Owner）と3回目（2番目のメンバー）は成功
            response = instance_double(Net::HTTPSuccess, body: { "id" => "ev" }.to_json, code: "200")
            allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
            response
          end
        end

        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:owner_event_created]).to be true
        expect(result[:member_events_created]).to eq(1)
        expect(result[:errors].size).to eq(1)
        expect(result[:errors].first).to match(/メンバー.*の予定作成失敗/)
      end
    end
  end

  describe "トークン管理" do
    before do
      group.update!(google_sub_calendar_id: "owner_sub_cal@group.calendar.google.com")
    end

    context "トークンが期限切れの場合" do
      before do
        owner.update!(google_oauth_token: {
          "access_token" => "expired_token",
          "refresh_token" => "valid_refresh_token",
          "expires_at" => (Time.current - 1.hour).to_i
        }.to_json)
      end

      it "リフレッシュトークンで再取得する" do
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

        # Calendar API のモック
        http_mock = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http_mock)
        allow(http_mock).to receive(:use_ssl=)

        allow(http_mock).to receive(:request) do |_req|
          response = instance_double(Net::HTTPSuccess, body: { "id" => "ev1" }.to_json, code: "200")
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          response
        end

        service = described_class.new(group, event_day)
        service.call

        owner.reload
        token_data = JSON.parse(owner.google_oauth_token)
        expect(token_data["access_token"]).to eq("new_access_token")
      end
    end

    context "リフレッシュトークンがない場合" do
      before do
        owner.update!(google_oauth_token: {
          "access_token" => "expired_token",
          "refresh_token" => nil,
          "expires_at" => (Time.current - 1.hour).to_i
        }.to_json)
      end

      it "エラーを返す" do
        service = described_class.new(group, event_day)
        result = service.call

        expect(result[:errors]).to include(match(/サブカレンダー作成失敗|リフレッシュトークン/))
      end
    end
  end
end
