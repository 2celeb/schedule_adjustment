# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Memberships", type: :request do
  describe "GET /api/groups/:share_token/members" do
    let(:owner) { create(:user, :with_discord, display_name: "オーナー") }
    let(:group) { create(:group, owner: owner) }

    before do
      create(:membership, user: owner, group: group, role: 'owner')
    end

    context "メンバーが存在する場合" do
      let!(:core_member) do
        user = create(:user, :with_discord, display_name: "コアメンバー")
        create(:membership, user: user, group: group, role: 'core')
        user
      end

      let!(:sub_member) do
        user = create(:user, :with_discord, display_name: "サブメンバー")
        create(:membership, user: user, group: group, role: 'sub')
        user
      end

      it "200 OK を返す" do
        get "/api/groups/#{group.share_token}/members"
        expect(response).to have_http_status(:ok)
      end

      it "グループIDを返す" do
        get "/api/groups/#{group.share_token}/members"
        body = JSON.parse(response.body)
        expect(body["group_id"]).to eq(group.id)
      end

      it "全メンバーを返す" do
        get "/api/groups/#{group.share_token}/members"
        body = JSON.parse(response.body)
        expect(body["members"].length).to eq(3)
      end

      it "メンバー情報に必要なフィールドが含まれる" do
        get "/api/groups/#{group.share_token}/members"
        body = JSON.parse(response.body)
        member = body["members"].find { |m| m["user_id"] == core_member.id }

        expect(member["id"]).to be_present
        expect(member["user_id"]).to eq(core_member.id)
        expect(member["display_name"]).to eq("コアメンバー")
        expect(member["discord_screen_name"]).to be_present
        expect(member["role"]).to eq("core")
        expect(member).to have_key("auth_locked")
        expect(member).to have_key("anonymized")
      end

      it "認証なしでアクセスできる" do
        get "/api/groups/#{group.share_token}/members"
        expect(response).to have_http_status(:ok)
      end

      it "作成順にソートされる" do
        get "/api/groups/#{group.share_token}/members"
        body = JSON.parse(response.body)
        member_ids = body["members"].map { |m| m["user_id"] }
        expect(member_ids).to eq([owner.id, core_member.id, sub_member.id])
      end
    end

    context "Google 連携済みメンバーがいる場合" do
      let!(:google_member) do
        user = create(:user, :with_discord, :with_google, display_name: "Google連携メンバー")
        create(:membership, user: user, group: group, role: 'core')
        user
      end

      it "auth_locked が true で返される" do
        get "/api/groups/#{group.share_token}/members"
        body = JSON.parse(response.body)
        member = body["members"].find { |m| m["user_id"] == google_member.id }
        expect(member["auth_locked"]).to be true
      end
    end

    context "存在しない share_token の場合" do
      it "404 Not Found を返す" do
        get "/api/groups/nonexistent_token/members"
        expect(response).to have_http_status(:not_found)
      end

      it "エラーレスポンスを返す" do
        get "/api/groups/nonexistent_token/members"
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "PATCH /api/memberships/:id" do
    let(:owner) { create(:user, :with_discord, :with_google) }
    let(:group) { create(:group, owner: owner) }
    let(:owner_session) { create(:session, user: owner) }
    let(:owner_headers) { { "Cookie" => "_session_token=#{owner_session.token}" } }
    let!(:owner_membership) { create(:membership, user: owner, group: group, role: 'owner') }

    let(:target_user) { create(:user, :with_discord) }
    let!(:target_membership) { create(:membership, user: target_user, group: group, role: 'sub') }

    context "Owner が sub を core に変更する場合" do
      it "200 OK を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: owner_headers
        expect(response).to have_http_status(:ok)
      end

      it "役割を core に更新する" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: owner_headers
        target_membership.reload
        expect(target_membership.role).to eq("core")
      end

      it "更新後のメンバーシップ情報を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: owner_headers
        body = JSON.parse(response.body)
        expect(body["membership"]["role"]).to eq("core")
        expect(body["membership"]["user_id"]).to eq(target_user.id)
      end
    end

    context "Owner が core を sub に変更する場合" do
      before { target_membership.update!(role: 'core') }

      it "役割を sub に更新する" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "sub" },
              headers: owner_headers
        target_membership.reload
        expect(target_membership.role).to eq("sub")
      end
    end

    context "不正な role を指定する場合" do
      it "owner を指定すると 400 Bad Request を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "owner" },
              headers: owner_headers
        expect(response).to have_http_status(:bad_request)
      end

      it "不正な値を指定すると 400 Bad Request を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "invalid" },
              headers: owner_headers
        expect(response).to have_http_status(:bad_request)
      end

      it "エラーレスポンスを返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "invalid" },
              headers: owner_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(body["error"]["details"]).to be_present
      end
    end

    context "Owner 自身の役割を変更しようとする場合" do
      it "403 Forbidden を返す" do
        patch "/api/memberships/#{owner_membership.id}",
              params: { role: "core" },
              headers: owner_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "役割を変更しない" do
        patch "/api/memberships/#{owner_membership.id}",
              params: { role: "core" },
              headers: owner_headers
        owner_membership.reload
        expect(owner_membership.role).to eq("owner")
      end
    end

    context "Owner でないユーザーが役割変更を試みる場合" do
      let(:non_owner) { create(:user, :with_discord, :with_google) }
      let(:non_owner_session) { create(:session, user: non_owner) }
      let(:non_owner_headers) { { "Cookie" => "_session_token=#{non_owner_session.token}" } }

      before do
        create(:membership, user: non_owner, group: group, role: 'core')
      end

      it "403 Forbidden を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: non_owner_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "エラーレスポンスを返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: non_owner_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("FORBIDDEN")
      end

      it "役割を変更しない" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: non_owner_headers
        target_membership.reload
        expect(target_membership.role).to eq("sub")
      end
    end

    context "セッションなしでアクセスする場合" do
      it "401 Unauthorized を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "期限切れセッションでアクセスする場合" do
      let(:expired_session) { create(:session, :expired, user: owner) }
      let(:expired_headers) { { "Cookie" => "_session_token=#{expired_session.token}" } }

      it "401 Unauthorized を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: expired_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しないメンバーシップIDを指定する場合" do
      it "404 Not Found を返す" do
        patch "/api/memberships/999999",
              params: { role: "core" },
              headers: owner_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "別グループの Owner が変更を試みる場合" do
      let(:other_owner) { create(:user, :with_discord, :with_google) }
      let(:other_group) { create(:group, owner: other_owner) }
      let(:other_owner_session) { create(:session, user: other_owner) }
      let(:other_owner_headers) { { "Cookie" => "_session_token=#{other_owner_session.token}" } }

      before do
        create(:membership, user: other_owner, group: other_group, role: 'owner')
      end

      it "403 Forbidden を返す" do
        patch "/api/memberships/#{target_membership.id}",
              params: { role: "core" },
              headers: other_owner_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
