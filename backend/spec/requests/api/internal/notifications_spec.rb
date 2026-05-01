# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Internal::Notifications", type: :request do
  let!(:owner) { create(:user, :with_discord) }
  let!(:group) { create(:group, owner: owner) }
  let(:bot_token) { "test_bot_token" }
  let(:headers) do
    {
      "Authorization" => "Bearer #{bot_token}",
      "Content-Type" => "application/json"
    }
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("INTERNAL_API_TOKEN").and_return(bot_token)
  end

  describe "POST /api/internal/notifications/remind" do
    it 'リマインドジョブをキューに追加する' do
      expect {
        post "/api/internal/notifications/remind",
             params: { group_id: group.id }.to_json,
             headers: headers
      }.to have_enqueued_job(RemindJob).with(group.id)

      expect(response).to have_http_status(:accepted)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("リマインドジョブ")
    end

    it 'group_id なしで全グループ対象のジョブをキューに追加する' do
      expect {
        post "/api/internal/notifications/remind",
             params: {}.to_json,
             headers: headers
      }.to have_enqueued_job(RemindJob).with(nil)

      expect(response).to have_http_status(:accepted)
    end

    it '存在しないグループ ID の場合は 404 を返す' do
      post "/api/internal/notifications/remind",
           params: { group_id: 999999 }.to_json,
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'Bot トークンなしの場合は 401 を返す' do
      post "/api/internal/notifications/remind",
           params: { group_id: group.id }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/internal/notifications/daily" do
    it '当日通知ジョブをキューに追加する' do
      expect {
        post "/api/internal/notifications/daily",
             params: { group_id: group.id }.to_json,
             headers: headers
      }.to have_enqueued_job(DailyNotifyJob).with(group.id)

      expect(response).to have_http_status(:accepted)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("当日通知ジョブ")
    end

    it 'group_id なしで全グループ対象のジョブをキューに追加する' do
      expect {
        post "/api/internal/notifications/daily",
             params: {}.to_json,
             headers: headers
      }.to have_enqueued_job(DailyNotifyJob).with(nil)

      expect(response).to have_http_status(:accepted)
    end

    it '存在しないグループ ID の場合は 404 を返す' do
      post "/api/internal/notifications/daily",
           params: { group_id: 999999 }.to_json,
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'Bot トークンなしの場合は 401 を返す' do
      post "/api/internal/notifications/daily",
           params: { group_id: group.id }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
