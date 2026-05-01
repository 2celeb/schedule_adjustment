# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::CalendarSyncs", type: :request do
  describe "POST /api/groups/:share_token/calendar_sync" do
    let(:owner) { create(:user, :with_google) }
    let(:group) { create(:group, owner: owner) }
    let!(:owner_membership) { create(:membership, user: owner, group: group, role: 'owner') }

    # ゆるい識別（X-User-Id ヘッダー）で認証するメンバー
    let(:member) { create(:user) }
    let!(:member_membership) { create(:membership, user: member, group: group, role: 'sub') }
    let(:loose_headers) { { "X-User-Id" => member.id.to_s } }

    # Cookie セッションで認証するメンバー
    let(:session_record) { create(:session, user: owner) }
    let(:cookie_headers) { { "Cookie" => "_session_token=#{session_record.token}" } }

    context "ゆるい識別で同期をトリガーする場合" do
      it "202 Accepted を返す" do
        allow(FreebusyFetchJob).to receive(:perform_later)
        post "/api/groups/#{group.share_token}/calendar_sync", headers: loose_headers
        expect(response).to have_http_status(:accepted)
      end

      it "同期キュー追加メッセージを返す" do
        allow(FreebusyFetchJob).to receive(:perform_later)
        post "/api/groups/#{group.share_token}/calendar_sync", headers: loose_headers
        body = JSON.parse(response.body)
        expect(body["message"]).to eq("カレンダー同期をキューに追加しました。")
      end

      it "日付範囲（当月）を返す" do
        allow(FreebusyFetchJob).to receive(:perform_later)
        post "/api/groups/#{group.share_token}/calendar_sync", headers: loose_headers
        body = JSON.parse(response.body)
        expect(body["date_range"]["start"]).to eq(Date.current.beginning_of_month.iso8601)
        expect(body["date_range"]["end"]).to eq(Date.current.end_of_month.iso8601)
      end

      it "FreebusyFetchJob を force: true でキューに投入する" do
        expect(FreebusyFetchJob).to receive(:perform_later).with(
          group.id,
          Date.current.beginning_of_month.iso8601,
          Date.current.end_of_month.iso8601,
          force: true
        )
        post "/api/groups/#{group.share_token}/calendar_sync", headers: loose_headers
      end
    end

    context "Cookie セッションで同期をトリガーする場合" do
      it "202 Accepted を返す" do
        allow(FreebusyFetchJob).to receive(:perform_later)
        post "/api/groups/#{group.share_token}/calendar_sync", headers: cookie_headers
        expect(response).to have_http_status(:accepted)
      end

      it "FreebusyFetchJob をキューに投入する" do
        expect(FreebusyFetchJob).to receive(:perform_later).with(
          group.id,
          anything,
          anything,
          force: true
        )
        post "/api/groups/#{group.share_token}/calendar_sync", headers: cookie_headers
      end
    end

    context "認証なしでアクセスする場合" do
      it "401 Unauthorized を返す" do
        post "/api/groups/#{group.share_token}/calendar_sync"
        expect(response).to have_http_status(:unauthorized)
      end

      it "エラーレスポンスを返す" do
        post "/api/groups/#{group.share_token}/calendar_sync"
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "存在しない share_token を指定する場合" do
      it "404 Not Found を返す" do
        post "/api/groups/nonexistent_token/calendar_sync", headers: loose_headers
        expect(response).to have_http_status(:not_found)
      end

      it "エラーレスポンスを返す" do
        post "/api/groups/nonexistent_token/calendar_sync", headers: loose_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NOT_FOUND")
      end
    end

    context "Google 連携済みメンバーがいない場合" do
      # Google 未連携の Owner でグループを作成
      let(:plain_owner) { create(:user) }
      let(:plain_group) { create(:group, owner: plain_owner) }
      let!(:plain_owner_membership) { create(:membership, user: plain_owner, group: plain_group, role: 'owner') }
      let(:plain_member) { create(:user) }
      let!(:plain_member_membership) { create(:membership, user: plain_member, group: plain_group, role: 'sub') }
      let(:plain_headers) { { "X-User-Id" => plain_member.id.to_s } }

      it "422 Unprocessable Entity を返す" do
        post "/api/groups/#{plain_group.share_token}/calendar_sync", headers: plain_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "エラーレスポンスを返す" do
        post "/api/groups/#{plain_group.share_token}/calendar_sync", headers: plain_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NO_CONNECTED_MEMBERS")
      end

      it "FreebusyFetchJob をキューに投入しない" do
        expect(FreebusyFetchJob).not_to receive(:perform_later)
        post "/api/groups/#{plain_group.share_token}/calendar_sync", headers: plain_headers
      end
    end
  end
end
