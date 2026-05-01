# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Internal::Groups", type: :request do
  let(:bot_token) { "test_internal_api_token" }
  let(:auth_headers) { { "Authorization" => "Bearer #{bot_token}" } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("INTERNAL_API_TOKEN").and_return(bot_token)
  end

  describe "Bot トークン認証" do
    let!(:owner) { create(:user, :with_discord) }
    let!(:group) { create(:group, owner: owner) }

    context "トークンが未設定の場合" do
      it "401 を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status"

        expect(response).to have_http_status(:unauthorized)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "トークンが不正な場合" do
      it "401 を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: { "Authorization" => "Bearer invalid_token" }

        expect(response).to have_http_status(:unauthorized)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "Authorization ヘッダーの形式が不正な場合" do
      it "Bearer プレフィックスなしの場合は 401 を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: { "Authorization" => bot_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "環境変数 INTERNAL_API_TOKEN が未設定の場合" do
      before do
        allow(ENV).to receive(:[]).with("INTERNAL_API_TOKEN").and_return(nil)
      end

      it "401 を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/internal/groups" do
    let(:owner_discord_user_id) { "discord_owner_123" }
    let(:valid_params) do
      {
        guild_id: "guild_123",
        name: "テストサーバー",
        owner_discord_user_id: owner_discord_user_id,
        owner_discord_screen_name: "オーナー太郎",
        default_start_time: "19:00",
        default_end_time: "22:00",
        locale: "ja"
      }
    end

    context "有効なパラメータの場合" do
      it "グループを作成する" do
        expect {
          post "/api/internal/groups", params: valid_params, headers: auth_headers
        }.to change(Group, :count).by(1)
          .and change(User, :count).by(1)
          .and change(Membership, :count).by(1)
          .and change(DiscordConfig, :count).by(1)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["group"]["name"]).to eq("テストサーバー")
        expect(json["group"]["event_name"]).to eq("テストサーバーの活動")
        expect(json["group"]["default_start_time"]).to eq("19:00")
        expect(json["group"]["default_end_time"]).to eq("22:00")
        expect(json["group"]["locale"]).to eq("ja")
      end

      it "Owner ユーザーを Discord 情報で作成する" do
        post "/api/internal/groups", params: valid_params, headers: auth_headers

        owner = User.find_by(discord_user_id: owner_discord_user_id)
        expect(owner).to be_present
        expect(owner.discord_screen_name).to eq("オーナー太郎")
        expect(owner.display_name).to eq("オーナー太郎")
      end

      it "Owner のメンバーシップを owner ロールで作成する" do
        post "/api/internal/groups", params: valid_params, headers: auth_headers

        json = response.parsed_body
        group = Group.find(json["group"]["id"])
        owner = User.find_by(discord_user_id: owner_discord_user_id)
        membership = Membership.find_by(user: owner, group: group)

        expect(membership).to be_present
        expect(membership.role).to eq("owner")
      end

      it "DiscordConfig を作成する" do
        post "/api/internal/groups", params: valid_params.merge(default_channel_id: "channel_456"), headers: auth_headers

        json = response.parsed_body
        group = Group.find(json["group"]["id"])
        config = group.discord_config

        expect(config).to be_present
        expect(config.guild_id).to eq("guild_123")
        expect(config.default_channel_id).to eq("channel_456")
      end

      it "share_token が自動生成される" do
        post "/api/internal/groups", params: valid_params, headers: auth_headers

        json = response.parsed_body
        expect(json["group"]["share_token"]).to be_present
        expect(json["group"]["share_token"].length).to eq(21)
      end
    end

    context "既存の Discord ユーザーが Owner の場合" do
      let!(:existing_user) { create(:user, :with_discord, discord_user_id: owner_discord_user_id) }

      it "既存ユーザーを Owner として使用する" do
        expect {
          post "/api/internal/groups", params: valid_params, headers: auth_headers
        }.not_to change(User, :count)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        group = Group.find(json["group"]["id"])
        expect(group.owner_id).to eq(existing_user.id)
      end
    end

    context "同じ guild_id のグループが既に存在する場合" do
      let!(:existing_owner) { create(:user, :with_discord) }
      let!(:existing_group) { create(:group, owner: existing_owner) }
      let!(:existing_config) { create(:discord_config, group: existing_group, guild_id: "guild_123") }

      it "既存グループを返す（新規作成しない）" do
        expect {
          post "/api/internal/groups", params: valid_params, headers: auth_headers
        }.not_to change(Group, :count)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["group"]["id"]).to eq(existing_group.id)
      end
    end

    context "必須パラメータが不足している場合" do
      it "guild_id がない場合は 400 を返す" do
        post "/api/internal/groups",
             params: valid_params.except(:guild_id),
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "owner_discord_user_id がない場合は 400 を返す" do
        post "/api/internal/groups",
             params: valid_params.except(:owner_discord_user_id),
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "name が未指定の場合" do
      it "デフォルト名でグループを作成する" do
        post "/api/internal/groups",
             params: valid_params.merge(name: nil),
             headers: auth_headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["group"]["name"]).to eq("新規グループ")
        expect(json["group"]["event_name"]).to eq("新規グループの活動")
      end
    end

    context "locale が未指定の場合" do
      it "デフォルトで ja を使用する" do
        post "/api/internal/groups",
             params: valid_params.except(:locale),
             headers: auth_headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json["group"]["locale"]).to eq("ja")
      end
    end
  end

  describe "POST /api/internal/groups/:id/sync_members" do
    let!(:owner) { create(:user, :with_discord, discord_user_id: "owner_discord_id") }
    let!(:group) { create(:group, owner: owner) }
    let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

    let(:members_params) do
      {
        members: [
          { discord_user_id: "member_1", discord_screen_name: "メンバー1" },
          { discord_user_id: "member_2", discord_screen_name: "メンバー2", display_name: "カスタム名2" }
        ]
      }
    end

    context "新規メンバーの追加" do
      it "メンバーを一括登録する" do
        expect {
          post "/api/internal/groups/#{group.id}/sync_members",
               params: members_params,
               headers: auth_headers
        }.to change(User, :count).by(2)
          .and change(Membership, :count).by(2)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["results"]["added"].length).to eq(2)
      end

      it "display_name が指定されている場合はそれを使用する" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: members_params,
             headers: auth_headers

        user2 = User.find_by(discord_user_id: "member_2")
        expect(user2.display_name).to eq("カスタム名2")
      end

      it "display_name が未指定の場合は discord_screen_name を使用する" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: members_params,
             headers: auth_headers

        user1 = User.find_by(discord_user_id: "member_1")
        expect(user1.display_name).to eq("メンバー1")
      end

      it "新規メンバーは sub ロールで登録される" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: members_params,
             headers: auth_headers

        user1 = User.find_by(discord_user_id: "member_1")
        membership = Membership.find_by(user: user1, group: group)
        expect(membership.role).to eq("sub")
      end
    end

    context "既存メンバーの更新" do
      let!(:existing_user) { create(:user, :with_discord, discord_user_id: "member_1", discord_screen_name: "旧名前") }
      let!(:existing_membership) { create(:membership, user: existing_user, group: group) }

      it "Discord スクリーン名を更新する" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: members_params,
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["results"]["updated"].length).to eq(1)
        expect(json["results"]["updated"][0]["discord_user_id"]).to eq("member_1")

        existing_user.reload
        expect(existing_user.discord_screen_name).to eq("メンバー1")
      end

      it "メンバーシップを重複作成しない" do
        expect {
          post "/api/internal/groups/#{group.id}/sync_members",
               params: members_params,
               headers: auth_headers
        }.to change(Membership, :count).by(1) # member_2 のみ追加
      end
    end

    context "Owner の discord_user_id と一致するメンバーの場合" do
      it "スキップする" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: {
               members: [
                 { discord_user_id: "owner_discord_id", discord_screen_name: "オーナー" }
               ]
             },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["results"]["skipped"].length).to eq(1)
        expect(json["results"]["skipped"][0]["reason"]).to eq("owner")
      end
    end

    context "メンバー上限に達している場合" do
      before do
        # 既に Owner を含めて 20 名にする（Owner + 19名）
        19.times do |i|
          user = create(:user, :with_discord, discord_user_id: "existing_#{i}")
          create(:membership, user: user, group: group)
        end
      end

      it "上限超過のメンバーはエラーとして記録する" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: {
               members: [
                 { discord_user_id: "new_member", discord_screen_name: "新メンバー" }
               ]
             },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["results"]["errors"].length).to eq(1)
        expect(json["results"]["errors"][0]["discord_user_id"]).to eq("new_member")
      end
    end

    context "members パラメータが配列でない場合" do
      it "400 を返す" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: { members: "invalid" },
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "discord_user_id が空のメンバーがある場合" do
      it "エラーとして記録し、他のメンバーは処理する" do
        post "/api/internal/groups/#{group.id}/sync_members",
             params: {
               members: [
                 { discord_user_id: nil, discord_screen_name: "名前なし" },
                 { discord_user_id: "valid_member", discord_screen_name: "有効メンバー" }
               ]
             },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["results"]["errors"].length).to eq(1)
        expect(json["results"]["added"].length).to eq(1)
      end
    end

    context "存在しないグループ ID の場合" do
      it "404 を返す" do
        post "/api/internal/groups/999999/sync_members",
             params: members_params,
             headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end

  describe "GET /api/internal/groups/:id/weekly_status" do
    let!(:owner) { create(:user, :with_discord) }
    let!(:group) { create(:group, owner: owner) }
    let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }
    let!(:member1) { create(:user, :with_discord) }
    let!(:member2) { create(:user, :with_discord) }
    let!(:membership1) { create(:membership, :core, user: member1, group: group) }
    let!(:membership2) { create(:membership, user: member2, group: group) }

    context "参加可否データがある場合" do
      before do
        # 今週の月曜日を基準にデータを作成
        monday = Date.current.beginning_of_week(:monday)
        create(:availability, :ok, user: member1, group: group, date: monday)
        create(:availability, :ng, user: member1, group: group, date: monday + 1.day)
        create(:availability, :ok, user: member2, group: group, date: monday)
      end

      it "週次入力状況を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["group"]["id"]).to eq(group.id)
        expect(json["group"]["name"]).to eq(group.name)
        expect(json["group"]["share_token"]).to eq(group.share_token)
        expect(json["week_start"]).to be_present
        expect(json["week_end"]).to be_present
        expect(json["members"].length).to eq(3) # Owner + member1 + member2
      end

      it "各メンバーの入力状況を含む" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: auth_headers

        json = response.parsed_body
        member1_status = json["members"].find { |m| m["user_id"] == member1.id }

        expect(member1_status["display_name"]).to eq(member1.display_name)
        expect(member1_status["discord_user_id"]).to eq(member1.discord_user_id)
        expect(member1_status["role"]).to eq("core")
        expect(member1_status["dates"].length).to eq(7)
        expect(member1_status["filled_count"]).to eq(2)
        expect(member1_status["total_days"]).to eq(7)
      end

      it "各日付の入力状態を含む" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: auth_headers

        json = response.parsed_body
        member1_status = json["members"].find { |m| m["user_id"] == member1.id }
        monday = Date.current.beginning_of_week(:monday)

        monday_data = member1_status["dates"].find { |d| d["date"] == monday.to_s }
        expect(monday_data["status"]).to eq(1)
        expect(monday_data["filled"]).to be true

        tuesday_data = member1_status["dates"].find { |d| d["date"] == (monday + 1.day).to_s }
        expect(tuesday_data["status"]).to eq(-1)
        expect(tuesday_data["filled"]).to be true
      end
    end

    context "参加可否データがない場合" do
      it "全メンバーの filled_count が 0 を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        json["members"].each do |member|
          expect(member["filled_count"]).to eq(0)
          member["dates"].each do |date_data|
            expect(date_data["status"]).to be_nil
            expect(date_data["filled"]).to be false
          end
        end
      end
    end

    context "auto_schedule_rule で week_start_day が設定されている場合" do
      before do
        create(:auto_schedule_rule, group: group, week_start_day: 0) # 日曜始まり
      end

      it "week_start_day に基づいた週の範囲を返す" do
        get "/api/internal/groups/#{group.id}/weekly_status",
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        week_start = Date.parse(json["week_start"])
        expect(week_start.wday).to eq(0) # 日曜日
      end
    end

    context "存在しないグループ ID の場合" do
      it "404 を返す" do
        get "/api/internal/groups/999999/weekly_status",
            headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]["code"]).to eq("NOT_FOUND")
      end
    end
  end
end
