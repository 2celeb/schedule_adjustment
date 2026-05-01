# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::EventDays", type: :request do
  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user) }
  let!(:group) { create(:group, :with_times, owner: owner) }
  let!(:owner_session) { create(:session, user: owner) }

  describe "GET /api/groups/:group_id/event_days" do
    let!(:event_day1) { create(:event_day, group: group, date: Date.new(2026, 5, 5), confirmed: true, confirmed_at: Time.current) }
    let!(:event_day2) { create(:event_day, group: group, date: Date.new(2026, 5, 12)) }
    let!(:other_month_event) { create(:event_day, group: group, date: Date.new(2026, 6, 1)) }

    context "月を指定した場合" do
      it "指定月の活動日一覧を返す" do
        get "/api/groups/#{group.id}/event_days", params: { month: "2026-05" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["event_days"].size).to eq(2)
        dates = json["event_days"].map { |ed| ed["date"] }
        expect(dates).to eq(["2026-05-05", "2026-05-12"])
      end

      it "他の月の活動日は含まれない" do
        get "/api/groups/#{group.id}/event_days", params: { month: "2026-05" }

        json = response.parsed_body
        dates = json["event_days"].map { |ed| ed["date"] }
        expect(dates).not_to include("2026-06-01")
      end
    end

    context "月を指定しない場合" do
      it "当月の活動日一覧を返す" do
        create(:event_day, group: group, date: Date.current.beginning_of_month + 1.day)

        get "/api/groups/#{group.id}/event_days"

        expect(response).to have_http_status(:ok)
      end
    end

    context "不正な月形式の場合" do
      it "400 を返す" do
        get "/api/groups/#{group.id}/event_days", params: { month: "invalid" }

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "存在しないグループの場合" do
      it "404 を返す" do
        get "/api/groups/999999/event_days"

        expect(response).to have_http_status(:not_found)
      end
    end

    it "認証なしでアクセスできる" do
      get "/api/groups/#{group.id}/event_days", params: { month: "2026-05" }

      expect(response).to have_http_status(:ok)
    end

    it "デフォルト時間が適用される（start_time/end_time が null の場合）" do
      get "/api/groups/#{group.id}/event_days", params: { month: "2026-05" }

      json = response.parsed_body
      # event_day2 は start_time/end_time が null なのでグループデフォルトが適用される
      ed2 = json["event_days"].find { |ed| ed["date"] == "2026-05-12" }
      expect(ed2["start_time"]).to eq("19:00")
      expect(ed2["end_time"]).to eq("22:00")
      expect(ed2["custom_time"]).to be false
    end

    it "カスタム時間が設定されている場合は custom_time が true" do
      event_day2.update!(start_time: "18:00", end_time: "21:00")

      get "/api/groups/#{group.id}/event_days", params: { month: "2026-05" }

      json = response.parsed_body
      ed2 = json["event_days"].find { |ed| ed["date"] == "2026-05-12" }
      expect(ed2["start_time"]).to eq("18:00")
      expect(ed2["end_time"]).to eq("21:00")
      expect(ed2["custom_time"]).to be true
    end
  end

  describe "POST /api/groups/:group_id/event_days" do
    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      it "活動日を追加できる" do
        post "/api/groups/#{group.id}/event_days", params: {
          date: "2026-06-01"
        }

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["event_day"]["date"]).to eq("2026-06-01")
        expect(json["event_day"]["group_id"]).to eq(group.id)
      end

      it "活動時間を指定して追加できる" do
        post "/api/groups/#{group.id}/event_days", params: {
          date: "2026-06-01",
          start_time: "18:00",
          end_time: "21:00"
        }

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["event_day"]["start_time"]).to eq("18:00")
        expect(json["event_day"]["end_time"]).to eq("21:00")
        expect(json["event_day"]["custom_time"]).to be true
      end

      it "confirmed を指定して追加できる" do
        post "/api/groups/#{group.id}/event_days", params: {
          date: "2026-06-01",
          confirmed: true
        }

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["event_day"]["confirmed"]).to be true
      end

      it "日付なしの場合は 422 を返す" do
        post "/api/groups/#{group.id}/event_days", params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "同じ日付の重複は 422 を返す" do
        create(:event_day, group: group, date: "2026-06-01")

        post "/api/groups/#{group.id}/event_days", params: {
          date: "2026-06-01"
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        post "/api/groups/#{group.id}/event_days", params: {
          date: "2026-06-01"
        }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        post "/api/groups/#{group.id}/event_days", params: {
          date: "2026-06-01"
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/event_days/:id" do
    let!(:event_day) { create(:event_day, group: group, date: "2026-06-01") }

    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      it "活動時間を更新できる" do
        patch "/api/event_days/#{event_day.id}", params: {
          start_time: "18:00",
          end_time: "21:00"
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["event_day"]["start_time"]).to eq("18:00")
        expect(json["event_day"]["end_time"]).to eq("21:00")
        expect(json["event_day"]["custom_time"]).to be true
      end

      it "confirmed を更新できる" do
        patch "/api/event_days/#{event_day.id}", params: {
          confirmed: true
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["event_day"]["confirmed"]).to be true
      end

      it "パラメータが空の場合は 400 を返す" do
        patch "/api/event_days/#{event_day.id}"

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        patch "/api/event_days/#{event_day.id}", params: {
          start_time: "18:00"
        }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        patch "/api/event_days/#{event_day.id}", params: {
          start_time: "18:00"
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しない活動日の場合" do
      before { set_session_cookie(owner_session) }

      it "404 を返す" do
        patch "/api/event_days/999999", params: { start_time: "18:00" }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/event_days/:id" do
    let!(:event_day) { create(:event_day, group: group, date: "2026-06-01") }

    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      it "活動日を削除できる" do
        expect {
          delete "/api/event_days/#{event_day.id}"
        }.to change(EventDay, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        delete "/api/event_days/#{event_day.id}"

        expect(response).to have_http_status(:forbidden)
        expect(EventDay.exists?(event_day.id)).to be true
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        delete "/api/event_days/#{event_day.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しない活動日の場合" do
      before { set_session_cookie(owner_session) }

      it "404 を返す" do
        delete "/api/event_days/999999"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
