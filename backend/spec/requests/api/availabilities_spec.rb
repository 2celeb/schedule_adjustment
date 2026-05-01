# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Availabilities", type: :request do
  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user, display_name: "オーナー") }
  let!(:group) do
    create(:group, :with_times, :with_threshold,
           owner: owner,
           name: "テストグループ",
           event_name: "テスト活動",
           locale: "ja")
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

  let!(:core_member) { create(:user, display_name: "コアメンバー") }
  let!(:core_membership) { create(:membership, :core, user: core_member, group: group) }

  let!(:sub_member) { create(:user, display_name: "サブメンバー") }
  let!(:sub_membership) { create(:membership, user: sub_member, group: group) }

  describe "GET /api/groups/:share_token/availabilities" do
    let(:today) { Date.current }
    let(:month_str) { today.strftime("%Y-%m") }

    context "認証なしでアクセスする場合" do
      it "グループ情報、メンバー、参加可否、活動日、集計を返す" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        # グループ情報
        expect(json["group"]["id"]).to eq(group.id)
        expect(json["group"]["name"]).to eq("テストグループ")
        expect(json["group"]["locale"]).to eq("ja")
        expect(json["group"]["threshold_n"]).to eq(3)
        expect(json["group"]["threshold_target"]).to eq("core")
        expect(json["group"]["default_start_time"]).to eq("19:00")
        expect(json["group"]["default_end_time"]).to eq("22:00")

        # メンバー
        expect(json["members"].size).to eq(3)
        member_names = json["members"].map { |m| m["display_name"] }
        expect(member_names).to include("オーナー", "コアメンバー", "サブメンバー")

        # 集計（全日分が存在する）
        expect(json["summary"]).to be_present
      end
    end

    context "参加可否データがある場合" do
      before do
        create(:availability, :ok, user: core_member, group: group, date: today)
        create(:availability, :ng, user: sub_member, group: group, date: today, comment: "出張")
      end

      it "参加可否データを正しく返す" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        date_key = today.iso8601
        avails = json["availabilities"][date_key]
        expect(avails[core_member.id.to_s]["status"]).to eq(1)
        expect(avails[sub_member.id.to_s]["status"]).to eq(-1)
        expect(avails[sub_member.id.to_s]["comment"]).to eq("出張")
      end

      it "集計データが正しい" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        date_key = today.iso8601
        summary = json["summary"][date_key]

        expect(summary["ok"]).to eq(1)
        expect(summary["ng"]).to eq(1)
        expect(summary["none"]).to eq(1) # owner は未入力
        expect(summary["maybe"]).to eq(0)
      end
    end

    context "活動日がある場合" do
      before do
        create(:event_day, :confirmed, :with_times, group: group, date: today)
      end

      it "活動日データを返す" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        date_key = today.iso8601
        event_day = json["event_days"][date_key]

        expect(event_day).to be_present
        expect(event_day["confirmed"]).to be true
        expect(event_day["start_time"]).to eq("19:00")
        expect(event_day["end_time"]).to eq("22:00")
      end
    end

    context "活動日のデフォルト時間適用" do
      before do
        create(:event_day, :confirmed, group: group, date: today, start_time: nil, end_time: nil)
      end

      it "start_time/end_time が null の場合はグループのデフォルト値を使用する" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        date_key = today.iso8601
        event_day = json["event_days"][date_key]

        expect(event_day["start_time"]).to eq("19:00")
        expect(event_day["end_time"]).to eq("22:00")
        expect(event_day["custom_time"]).to be false
      end
    end

    context "month パラメータが省略された場合" do
      it "当月のデータを返す" do
        get "/api/groups/#{group.share_token}/availabilities"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["summary"]).to be_present

        # 当月の日数分の集計が存在する
        days_in_month = Date.current.end_of_month.day
        expect(json["summary"].size).to eq(days_in_month)
      end
    end

    context "month パラメータが不正な場合" do
      it "400 を返す" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: "invalid" }

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "存在しない share_token の場合" do
      it "404 を返す" do
        get "/api/groups/invalid_token/availabilities"

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "PUT /api/groups/:share_token/availabilities" do
    let(:today) { Date.current }
    let(:tomorrow) { Date.current + 1.day }

    context "ゆるい識別（X-User-Id ヘッダー）で更新する場合" do
      it "参加可否を新規作成できる" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"].size).to eq(1)
        expect(json["updated"][0]["status"]).to eq(1)
        expect(json["updated"][0]["date"]).to eq(tomorrow.iso8601)
      end

      it "参加可否を更新（upsert）できる" do
        create(:availability, :ok, user: sub_member, group: group, date: tomorrow)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: -1, comment: "予定あり" }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"][0]["status"]).to eq(-1)
        expect(json["updated"][0]["comment"]).to eq("予定あり")

        # DB の値も確認
        availability = Availability.find_by(user: sub_member, group: group, date: tomorrow)
        expect(availability.status).to eq(-1)
        expect(availability.comment).to eq("予定あり")
      end

      it "複数日を一括更新できる" do
        day_after = tomorrow + 1.day

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil },
                { date: day_after.iso8601, status: -1, comment: "出張" }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"].size).to eq(2)
      end
    end

    context "Cookie 認証で更新する場合" do
      let!(:core_session) { create(:session, user: core_member) }

      before { set_session_cookie(core_session) }

      it "参加可否を更新できる" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: core_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 0, comment: "未定" }
              ]
            },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"][0]["status"]).to eq(0)
        expect(json["updated"][0]["comment"]).to eq("未定")
      end
    end

    context "コメントの保存制御" do
      it "status が ○ (1) の場合はコメントを保存しない" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: "このコメントは無視される" }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"][0]["comment"]).to be_nil

        availability = Availability.find_by(user: sub_member, group: group, date: tomorrow)
        expect(availability.comment).to be_nil
      end

      it "status が × (-1) の場合はコメントを保存する" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: -1, comment: "出張のため" }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"][0]["comment"]).to eq("出張のため")
      end

      it "status が △ (0) の場合はコメントを保存する" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 0, comment: "遅れるかも" }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"][0]["comment"]).to eq("遅れるかも")
      end
    end

    context "過去日付の変更制御" do
      let(:yesterday) { Date.current - 1.day }

      it "一般メンバーは過去日付を変更できない" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: yesterday.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]["details"][0]["message"]).to include("過去の日付")
      end

      it "Owner は過去日付を変更できる" do
        owner_session = create(:session, user: owner)
        set_session_cookie(owner_session)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: owner.id,
              availabilities: [
                { date: yesterday.iso8601, status: 1, comment: nil }
              ]
            },
            as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["updated"][0]["date"]).to eq(yesterday.iso8601)
      end
    end

    context "変更履歴の記録" do
      it "参加可否の変更時に AvailabilityLog が作成される" do
        expect {
          put "/api/groups/#{group.share_token}/availabilities",
              params: {
                user_id: sub_member.id,
                availabilities: [
                  { date: tomorrow.iso8601, status: 1, comment: nil }
                ]
              },
              headers: { "X-User-Id" => sub_member.id.to_s },
              as: :json
        }.to change(AvailabilityLog, :count).by(1)

        log = AvailabilityLog.last
        expect(log.new_status).to eq(1)
        expect(log.user_id).to eq(sub_member.id)
      end

      it "status の更新時に変更前後の値が記録される" do
        create(:availability, :ok, user: sub_member, group: group, date: tomorrow)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: -1, comment: "変更" }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        log = AvailabilityLog.last
        expect(log.old_status).to eq(1)
        expect(log.new_status).to eq(-1)
      end
    end

    context "auto_synced のリセット" do
      it "手動変更時に auto_synced が false にリセットされる" do
        create(:availability, user: sub_member, group: group, date: tomorrow, status: -1, auto_synced: true)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)
        availability = Availability.find_by(user: sub_member, group: group, date: tomorrow)
        expect(availability.auto_synced).to be false
      end
    end

    context "認証エラー" do
      it "認証なしの場合は 401 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "auth_locked ユーザーが X-User-Id のみでアクセスした場合は 401 を返す" do
        locked_user = create(:user, :with_google)
        create(:membership, user: locked_user, group: group)

        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: locked_user.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => locked_user.id.to_s },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "他のユーザーの参加可否を変更しようとした場合" do
      it "403 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: core_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json["error"]["message"]).to include("他のユーザー")
      end
    end

    context "グループのメンバーでないユーザーの場合" do
      let!(:outsider) { create(:user) }

      it "403 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: outsider.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => outsider.id.to_s },
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "バリデーションエラー" do
      it "user_id が未指定の場合は 400 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it "availabilities が空の場合は 400 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: []
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:bad_request)
      end

      it "不正な status の場合は 422 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 2, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "不正な日付の場合は 422 を返す" do
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: "invalid-date", status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "トランザクションのロールバック" do
      it "一部にエラーがある場合は全件ロールバックされる" do
        yesterday = Date.current - 1.day

        expect {
          put "/api/groups/#{group.share_token}/availabilities",
              params: {
                user_id: sub_member.id,
                availabilities: [
                  { date: tomorrow.iso8601, status: 1, comment: nil },
                  { date: yesterday.iso8601, status: 1, comment: nil } # 過去日付 → エラー
                ]
              },
              headers: { "X-User-Id" => sub_member.id.to_s },
              as: :json
        }.not_to change(Availability, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "存在しない share_token の場合" do
      it "404 を返す" do
        put "/api/groups/invalid_token/availabilities",
            params: {
              user_id: sub_member.id,
              availabilities: [
                { date: tomorrow.iso8601, status: 1, comment: nil }
              ]
            },
            headers: { "X-User-Id" => sub_member.id.to_s },
            as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
