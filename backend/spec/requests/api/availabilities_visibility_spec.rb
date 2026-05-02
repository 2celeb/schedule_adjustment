# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Availabilities - 退会メンバーの可視性制御", type: :request do
  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user, :with_discord, display_name: "オーナー") }
  let!(:group) do
    create(:group, :with_times, owner: owner, name: "テストグループ", locale: "ja")
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }
  let!(:owner_session) { create(:session, user: owner) }

  let!(:active_member) { create(:user, :with_discord, display_name: "アクティブメンバー") }
  let!(:active_membership) { create(:membership, :core, user: active_member, group: group) }

  let(:today) { Date.current }
  let(:month_str) { today.strftime("%Y-%m") }

  # 退会メンバーのセットアップ
  # MemberAnonymizer を使って正規の退会処理を行う
  let!(:withdrawn_user) do
    user = create(:user, :with_discord, :with_google, display_name: "退会予定ユーザー")
    create(:membership, user: user, group: group)
    # 参加可否データを作成
    create(:availability, :ok, user: user, group: group, date: today)
    create(:availability, :ng, user: user, group: group, date: today + 1, comment: "退会前のコメント")
    # 退会処理を実行
    MemberAnonymizer.new(user, group).call
    user.reload
  end

  describe "GET /api/groups/:share_token/availabilities" do
    context "一般メンバー（認証なし）がアクセスする場合" do
      it "退会メンバーがメンバー一覧に含まれない" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).to include(owner.id, active_member.id)
        expect(member_ids).not_to include(withdrawn_user.id)
      end

      it "退会メンバーの参加可否データが含まれない" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        all_user_ids = json["availabilities"].values.flat_map(&:keys).map(&:to_i).uniq

        expect(all_user_ids).not_to include(withdrawn_user.id)
      end
    end

    context "一般メンバー（X-User-Id ヘッダー）がアクセスする場合" do
      it "退会メンバーがメンバー一覧に含まれない" do
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str },
            headers: { "X-User-Id" => active_member.id.to_s }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).not_to include(withdrawn_user.id)
      end

      it "退会メンバーの参加可否データも含まれない" do
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str },
            headers: { "X-User-Id" => active_member.id.to_s }

        json = response.parsed_body
        all_user_ids = json["availabilities"].values.flat_map(&:keys).map(&:to_i).uniq

        expect(all_user_ids).not_to include(withdrawn_user.id)
      end
    end

    context "Owner（Cookie 認証）がアクセスする場合" do
      before { set_session_cookie(owner_session) }

      it "退会メンバーがメンバー一覧に含まれる" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).to include(withdrawn_user.id)
      end

      it "退会メンバーが匿名化された表示名で表示される" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        withdrawn_member = json["members"].find { |m| m["id"] == withdrawn_user.id }

        expect(withdrawn_member).to be_present
        expect(withdrawn_member["display_name"]).to match(/\A退会済みメンバー\d+\z/)
        expect(withdrawn_member["discord_screen_name"]).to be_nil
        expect(withdrawn_member["role"]).to eq("withdrawn")
        expect(withdrawn_member["anonymized"]).to be true
      end

      it "退会メンバーの参加可否データが含まれる" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        today_data = json["availabilities"][today.iso8601]

        expect(today_data[withdrawn_user.id.to_s]).to be_present
        expect(today_data[withdrawn_user.id.to_s]["status"]).to eq(1)
      end

      it "退会メンバーのコメントも閲覧可能" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        tomorrow_data = json["availabilities"][(today + 1).iso8601]

        expect(tomorrow_data[withdrawn_user.id.to_s]).to be_present
        expect(tomorrow_data[withdrawn_user.id.to_s]["comment"]).to eq("退会前のコメント")
      end

      it "アクティブメンバーも正常に表示される" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        active = json["members"].find { |m| m["id"] == active_member.id }

        expect(active).to be_present
        expect(active["role"]).to eq("core")
        expect(active).not_to have_key("anonymized")
      end
    end

    context "Owner（X-User-Id ヘッダーのみ、Cookie なし、auth_locked=false）がアクセスする場合" do
      before { owner.update!(auth_locked: false) }

      it "X-User-Id でも Owner として識別され、退会メンバーが表示される" do
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str },
            headers: { "X-User-Id" => owner.id.to_s }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        member_ids = json["members"].map { |m| m["id"] }
        expect(member_ids).to include(withdrawn_user.id)
      end
    end

    context "退会メンバーのデータが対象月にない場合" do
      before { set_session_cookie(owner_session) }

      it "Owner でも退会メンバーはメンバー一覧に含まれない" do
        # 来月を指定（退会メンバーのデータは今月のみ）
        next_month = (today >> 1).strftime("%Y-%m")

        get "/api/groups/#{group.share_token}/availabilities", params: { month: next_month }

        json = response.parsed_body
        member_ids = json["members"].map { |m| m["id"] }

        # 対象月にデータがないので退会メンバーは表示されない
        expect(member_ids).not_to include(withdrawn_user.id)
      end
    end

    context "複数の退会メンバーがいる場合" do
      let!(:withdrawn_user2) do
        user = create(:user, :with_discord, display_name: "退会予定ユーザー2")
        create(:membership, user: user, group: group)
        create(:availability, :maybe, user: user, group: group, date: today, comment: "微妙")
        MemberAnonymizer.new(user, group).call
        user.reload
      end

      before { set_session_cookie(owner_session) }

      it "Owner は全ての退会メンバーを閲覧できる" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        member_ids = json["members"].map { |m| m["id"] }

        expect(member_ids).to include(withdrawn_user.id, withdrawn_user2.id)
      end

      it "各退会メンバーの匿名化名が異なる" do
        get "/api/groups/#{group.share_token}/availabilities", params: { month: month_str }

        json = response.parsed_body
        withdrawn_names = json["members"]
          .select { |m| m["anonymized"] == true }
          .map { |m| m["display_name"] }

        expect(withdrawn_names.uniq.size).to eq(withdrawn_names.size)
      end
    end
  end
end
