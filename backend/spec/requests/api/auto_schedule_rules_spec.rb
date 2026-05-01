# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::AutoScheduleRules", type: :request do
  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user) }
  let!(:group) { create(:group, owner: owner) }
  let!(:owner_session) { create(:session, user: owner) }

  describe "GET /api/groups/:group_id/auto_schedule_rule" do
    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      context "ルールが存在する場合" do
        let!(:rule) do
          create(:auto_schedule_rule, :with_limits,
            group: group,
            deprioritized_days: [0, 6],
            excluded_days: [0],
            week_start_day: 1,
            confirm_days_before: 3
          )
        end

        it "ルールを返す" do
          get "/api/groups/#{group.id}/auto_schedule_rule"

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          r = json["auto_schedule_rule"]
          expect(r["max_days_per_week"]).to eq(3)
          expect(r["min_days_per_week"]).to eq(1)
          expect(r["deprioritized_days"]).to eq([0, 6])
          expect(r["excluded_days"]).to eq([0])
          expect(r["week_start_day"]).to eq(1)
          expect(r["confirm_days_before"]).to eq(3)
          expect(r["confirm_time"]).to eq("21:00")
        end
      end

      context "ルールが存在しない場合" do
        it "デフォルト値でルールを返す" do
          get "/api/groups/#{group.id}/auto_schedule_rule"

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          r = json["auto_schedule_rule"]
          expect(r["week_start_day"]).to eq(1)
          expect(r["confirm_days_before"]).to eq(3)
          expect(r["deprioritized_days"]).to eq([])
          expect(r["excluded_days"]).to eq([])
        end
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        get "/api/groups/#{group.id}/auto_schedule_rule"

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        get "/api/groups/#{group.id}/auto_schedule_rule"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しないグループの場合" do
      before { set_session_cookie(owner_session) }

      it "404 を返す" do
        get "/api/groups/999999/auto_schedule_rule"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/groups/:group_id/auto_schedule_rule" do
    context "Owner が Cookie 認証済みの場合" do
      before { set_session_cookie(owner_session) }

      context "ルールが存在しない場合" do
        it "新規作成される" do
          expect {
            put "/api/groups/#{group.id}/auto_schedule_rule", params: {
              max_days_per_week: 3,
              min_days_per_week: 1,
              week_start_day: 1,
              confirm_days_before: 3
            }
          }.to change(AutoScheduleRule, :count).by(1)

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          r = json["auto_schedule_rule"]
          expect(r["max_days_per_week"]).to eq(3)
          expect(r["min_days_per_week"]).to eq(1)
        end
      end

      context "ルールが既に存在する場合" do
        let!(:rule) { create(:auto_schedule_rule, group: group) }

        it "ルールを更新できる" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            max_days_per_week: 5,
            min_days_per_week: 2,
            deprioritized_days: [0, 6],
            excluded_days: [0]
          }

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          r = json["auto_schedule_rule"]
          expect(r["max_days_per_week"]).to eq(5)
          expect(r["min_days_per_week"]).to eq(2)
          expect(r["deprioritized_days"]).to eq([0, 6])
          expect(r["excluded_days"]).to eq([0])
        end

        it "week_start_day を更新できる" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            week_start_day: 0
          }

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          expect(json["auto_schedule_rule"]["week_start_day"]).to eq(0)
        end

        it "confirm_days_before を更新できる" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            confirm_days_before: 5
          }

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          expect(json["auto_schedule_rule"]["confirm_days_before"]).to eq(5)
        end

        it "confirm_time を更新できる" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            confirm_time: "20:00"
          }

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          expect(json["auto_schedule_rule"]["confirm_time"]).to eq("20:00")
        end
      end

      context "バリデーションエラーの場合" do
        let!(:rule) { create(:auto_schedule_rule, group: group) }

        it "max_days_per_week が 0 の場合は 422 を返す" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            max_days_per_week: 0
          }

          expect(response).to have_http_status(:unprocessable_entity)
          json = response.parsed_body
          expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        end

        it "max_days_per_week が 8 の場合は 422 を返す" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            max_days_per_week: 8
          }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "min_days_per_week が max_days_per_week を超える場合は 422 を返す" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            max_days_per_week: 2,
            min_days_per_week: 5
          }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "week_start_day が 7 の場合は 422 を返す" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            week_start_day: 7
          }

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "confirm_days_before が 0 の場合は 422 を返す" do
          put "/api/groups/#{group.id}/auto_schedule_rule", params: {
            confirm_days_before: 0
          }

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "Owner 以外のユーザーが Cookie 認証済みの場合" do
      let!(:other_user) { create(:user) }
      let!(:other_session) { create(:session, user: other_user) }

      before { set_session_cookie(other_session) }

      it "403 を返す" do
        put "/api/groups/#{group.id}/auto_schedule_rule", params: {
          max_days_per_week: 3
        }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "認証なしの場合" do
      it "401 を返す" do
        put "/api/groups/#{group.id}/auto_schedule_rule", params: {
          max_days_per_week: 3
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
