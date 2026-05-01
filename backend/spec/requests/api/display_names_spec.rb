# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::DisplayNames", type: :request do
  describe "PATCH /api/users/:user_id/display_name" do
    let(:user) { create(:user, :with_discord, display_name: "元の名前") }
    let(:group) { create(:group, owner: create(:user, :with_discord)) }

    before do
      create(:membership, user: user, group: group, role: 'sub')
    end

    context "本人がゆるい識別で表示名を変更する場合" do
      let(:loose_headers) { { "X-User-Id" => user.id.to_s } }

      it "200 OK を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "新しい名前" },
              headers: loose_headers
        expect(response).to have_http_status(:ok)
      end

      it "表示名を更新する" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "新しい名前" },
              headers: loose_headers
        user.reload
        expect(user.display_name).to eq("新しい名前")
      end

      it "更新後のユーザー情報を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "新しい名前" },
              headers: loose_headers
        body = JSON.parse(response.body)
        expect(body["user"]["id"]).to eq(user.id)
        expect(body["user"]["display_name"]).to eq("新しい名前")
        expect(body["user"]["discord_screen_name"]).to eq(user.discord_screen_name)
      end
    end

    context "本人が Cookie 認証で表示名を変更する場合" do
      let(:google_user) { create(:user, :with_discord, :with_google, display_name: "Google連携ユーザー") }
      let(:session_record) { create(:session, user: google_user) }
      let(:cookie_headers) { { "Cookie" => "_session_token=#{session_record.token}" } }

      before do
        create(:membership, user: google_user, group: group, role: 'core')
      end

      it "200 OK を返す" do
        patch "/api/users/#{google_user.id}/display_name",
              params: { display_name: "変更後の名前" },
              headers: cookie_headers
        expect(response).to have_http_status(:ok)
      end

      it "表示名を更新する" do
        patch "/api/users/#{google_user.id}/display_name",
              params: { display_name: "変更後の名前" },
              headers: cookie_headers
        google_user.reload
        expect(google_user.display_name).to eq("変更後の名前")
      end
    end

    context "Owner が他のメンバーの表示名を変更する場合" do
      let(:owner) { group.owner }
      let(:owner_session) { create(:session, user: owner) }
      let(:owner_headers) { { "Cookie" => "_session_token=#{owner_session.token}" } }

      before do
        create(:membership, user: owner, group: group, role: 'owner')
      end

      it "200 OK を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "Ownerが変更" },
              headers: owner_headers
        expect(response).to have_http_status(:ok)
      end

      it "表示名を更新する" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "Ownerが変更" },
              headers: owner_headers
        user.reload
        expect(user.display_name).to eq("Ownerが変更")
      end
    end

    context "権限のないユーザーが他のメンバーの表示名を変更しようとする場合" do
      let(:other_user) { create(:user, :with_discord) }
      let(:other_headers) { { "X-User-Id" => other_user.id.to_s } }

      it "403 Forbidden を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "不正な変更" },
              headers: other_headers
        expect(response).to have_http_status(:forbidden)
      end

      it "表示名を変更しない" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "不正な変更" },
              headers: other_headers
        user.reload
        expect(user.display_name).to eq("元の名前")
      end
    end

    context "auth_locked ユーザーが X-User-Id のみでアクセスする場合" do
      let(:locked_user) { create(:user, :with_discord, :with_google, display_name: "ロック済み") }
      let(:locked_headers) { { "X-User-Id" => locked_user.id.to_s } }

      it "401 Unauthorized を返す" do
        patch "/api/users/#{locked_user.id}/display_name",
              params: { display_name: "変更" },
              headers: locked_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it "AUTH_LOCKED エラーコードを返す" do
        patch "/api/users/#{locked_user.id}/display_name",
              params: { display_name: "変更" },
              headers: locked_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("AUTH_LOCKED")
      end
    end

    context "認証なしでアクセスする場合" do
      it "401 Unauthorized を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "変更" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "表示名が空の場合" do
      let(:loose_headers) { { "X-User-Id" => user.id.to_s } }

      it "400 Bad Request を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "" },
              headers: loose_headers
        expect(response).to have_http_status(:bad_request)
      end

      it "エラーレスポンスを返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "" },
              headers: loose_headers
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "表示名が50文字を超える場合" do
      let(:loose_headers) { { "X-User-Id" => user.id.to_s } }

      it "400 Bad Request を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "あ" * 51 },
              headers: loose_headers
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "表示名がちょうど50文字の場合" do
      let(:loose_headers) { { "X-User-Id" => user.id.to_s } }

      it "200 OK を返す" do
        patch "/api/users/#{user.id}/display_name",
              params: { display_name: "あ" * 50 },
              headers: loose_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "存在しないユーザーIDを指定する場合" do
      let(:loose_headers) { { "X-User-Id" => user.id.to_s } }

      it "404 Not Found を返す" do
        patch "/api/users/999999/display_name",
              params: { display_name: "変更" },
              headers: loose_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
