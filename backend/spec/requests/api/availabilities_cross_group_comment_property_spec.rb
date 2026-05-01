# frozen_string_literal: true

require 'rails_helper'
require 'rantly'
require 'rantly/property'

# Feature: schedule-management-tool, Property 16: グループ間のコメント非公開
#
# 任意のグループ A のメンバーのコメントについて、グループ B（A ≠ B）の
# API レスポンスにコメントが含まれないことを検証する。
#
# Validates: 要件 10.3
RSpec.describe "Property 16: グループ間のコメント非公開", type: :request do
  # Rantly の property_of ヘルパー
  def property_of(&block)
    Rantly::Property.new(block)
  end

  # --- テストデータのセットアップ ---

  # グループ A
  let!(:owner_a) { create(:user, display_name: "オーナーA") }
  let!(:group_a) do
    create(:group, :with_times,
           owner: owner_a,
           name: "グループA",
           locale: "ja")
  end
  let!(:owner_a_membership) { create(:membership, :owner, user: owner_a, group: group_a) }

  # グループ B
  let!(:owner_b) { create(:user, display_name: "オーナーB") }
  let!(:group_b) do
    create(:group, :with_times,
           owner: owner_b,
           name: "グループB",
           locale: "ja")
  end
  let!(:owner_b_membership) { create(:membership, :owner, user: owner_b, group: group_b) }

  # 両グループに所属する共有メンバー（複数名）
  let!(:shared_members) do
    Array.new(3) do |i|
      user = create(:user, display_name: "共有メンバー#{i + 1}")
      create(:membership, user: user, group: group_a)
      create(:membership, user: user, group: group_b)
      user
    end
  end

  # グループ A のみに所属するメンバー
  let!(:member_only_a) do
    user = create(:user, display_name: "グループA専用メンバー")
    create(:membership, user: user, group: group_a)
    user
  end

  # グループ B のみに所属するメンバー
  let!(:member_only_b) do
    user = create(:user, display_name: "グループB専用メンバー")
    create(:membership, user: user, group: group_b)
    user
  end

  # 未来の日付を生成する
  def future_date(offset)
    Date.current + offset.days
  end

  describe "グループ A の API レスポンスにグループ B のコメントが含まれない" do
    it "任意の status・コメントの組み合わせで、他グループのコメントが漏洩しない" do
      property_of {
        # ランダムな共有メンバーを選択（インデックス 0〜2）
        member_index = range(0, 2)
        # status は × (-1) または △ (0)（コメントが保存される値）
        status = choose(-1, 0)
        # グループ A 用のコメント
        comment_a = "グループA_" + Rantly { sized(range(1, 20)) { string(:alpha) } }
        # グループ B 用のコメント（異なる内容）
        comment_b = "グループB_" + Rantly { sized(range(1, 20)) { string(:alpha) } }
        # 日付オフセット（1〜60日先）
        date_offset = range(1, 60)
        [member_index, status, comment_a, comment_b, date_offset]
      }.check(100) do |member_index, status, comment_a, comment_b, date_offset|
        member = shared_members[member_index]
        date = future_date(date_offset)

        # グループ A に参加可否とコメントを登録
        Availability.find_or_initialize_by(
          user: member, group: group_a, date: date
        ).update!(status: status, comment: comment_a, auto_synced: false)

        # グループ B に同じメンバー・同じ日付で異なるコメントを登録
        Availability.find_or_initialize_by(
          user: member, group: group_b, date: date
        ).update!(status: status, comment: comment_b, auto_synced: false)

        # グループ A の API レスポンスを取得
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group_a.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "グループ A の GET が失敗: date=#{date.iso8601}, response=#{response.body}"

        json_a = response.parsed_body
        date_key = date.iso8601
        user_key = member.id.to_s

        avail_a = json_a.dig("availabilities", date_key, user_key)
        expect(avail_a).to be_present,
          "グループ A のレスポンスに参加可否データが存在しない: " \
          "date=#{date_key}, user=#{user_key}"

        # グループ A のコメントが正しく返される
        expect(avail_a["comment"]).to eq(comment_a),
          "グループ A のコメントが不一致: " \
          "expected=#{comment_a.inspect}, got=#{avail_a['comment'].inspect}"

        # グループ B のコメントが含まれていない
        expect(avail_a["comment"]).not_to eq(comment_b),
          "グループ A のレスポンスにグループ B のコメントが漏洩: " \
          "comment_b=#{comment_b.inspect}"

        # グループ B の API レスポンスを取得
        get "/api/groups/#{group_b.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "グループ B の GET が失敗: date=#{date.iso8601}, response=#{response.body}"

        json_b = response.parsed_body
        avail_b = json_b.dig("availabilities", date_key, user_key)
        expect(avail_b).to be_present,
          "グループ B のレスポンスに参加可否データが存在しない: " \
          "date=#{date_key}, user=#{user_key}"

        # グループ B のコメントが正しく返される
        expect(avail_b["comment"]).to eq(comment_b),
          "グループ B のコメントが不一致: " \
          "expected=#{comment_b.inspect}, got=#{avail_b['comment'].inspect}"

        # グループ A のコメントが含まれていない
        expect(avail_b["comment"]).not_to eq(comment_a),
          "グループ B のレスポンスにグループ A のコメントが漏洩: " \
          "comment_a=#{comment_a.inspect}"
      end
    end
  end

  describe "レスポンス全体にわたるコメント漏洩チェック" do
    it "任意のグループ・日付について、レスポンス内の全コメントが対象グループのものだけである" do
      property_of {
        # 各メンバーに異なる status とコメントを生成
        statuses = Array.new(3) { choose(-1, 0) }
        comments_a = Array.new(3) { |i| "A専用コメント#{i}_" + Rantly { sized(range(1, 10)) { string(:alpha) } } }
        comments_b = Array.new(3) { |i| "B専用コメント#{i}_" + Rantly { sized(range(1, 10)) { string(:alpha) } } }
        date_offset = range(1, 60)
        [statuses, comments_a, comments_b, date_offset]
      }.check(100) do |statuses, comments_a, comments_b, date_offset|
        date = future_date(date_offset)

        # 全共有メンバーに両グループの参加可否を登録
        shared_members.each_with_index do |member, i|
          Availability.find_or_initialize_by(
            user: member, group: group_a, date: date
          ).update!(status: statuses[i], comment: comments_a[i], auto_synced: false)

          Availability.find_or_initialize_by(
            user: member, group: group_b, date: date
          ).update!(status: statuses[i], comment: comments_b[i], auto_synced: false)
        end

        # グループ A のレスポンスを取得
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group_a.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json_a = response.parsed_body

        # レスポンス内の全コメントを収集
        all_comments_in_a = []
        json_a["availabilities"].each_value do |date_data|
          date_data.each_value do |member_data|
            all_comments_in_a << member_data["comment"] if member_data["comment"].present?
          end
        end

        # グループ B のコメントが一切含まれていないことを確認
        comments_b.each do |cb|
          expect(all_comments_in_a).not_to include(cb),
            "グループ A のレスポンスにグループ B のコメントが含まれている: " \
            "leaked_comment=#{cb.inspect}, all_comments=#{all_comments_in_a.inspect}"
        end

        # グループ B のレスポンスを取得
        get "/api/groups/#{group_b.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json_b = response.parsed_body

        # レスポンス内の全コメントを収集
        all_comments_in_b = []
        json_b["availabilities"].each_value do |date_data|
          date_data.each_value do |member_data|
            all_comments_in_b << member_data["comment"] if member_data["comment"].present?
          end
        end

        # グループ A のコメントが一切含まれていないことを確認
        comments_a.each do |ca|
          expect(all_comments_in_b).not_to include(ca),
            "グループ B のレスポンスにグループ A のコメントが含まれている: " \
            "leaked_comment=#{ca.inspect}, all_comments=#{all_comments_in_b.inspect}"
        end
      end
    end
  end

  describe "グループ専用メンバーのコメントが他グループに漏洩しない" do
    it "グループ A 専用メンバーのコメントがグループ B のレスポンスに含まれない" do
      property_of {
        status = choose(-1, 0)
        comment = "A専用_" + Rantly { sized(range(1, 20)) { string(:alpha) } }
        date_offset = range(1, 60)
        [status, comment, date_offset]
      }.check(100) do |status, comment, date_offset|
        date = future_date(date_offset)

        # グループ A 専用メンバーにコメント付き参加可否を登録
        Availability.find_or_initialize_by(
          user: member_only_a, group: group_a, date: date
        ).update!(status: status, comment: comment, auto_synced: false)

        # グループ B のレスポンスを取得
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group_b.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok)
        json_b = response.parsed_body

        # レスポンス内の全コメントを収集
        all_comments_in_b = []
        json_b["availabilities"].each_value do |date_data|
          date_data.each_value do |member_data|
            all_comments_in_b << member_data["comment"] if member_data["comment"].present?
          end
        end

        # グループ A 専用メンバーのコメントが含まれていないことを確認
        expect(all_comments_in_b).not_to include(comment),
          "グループ B のレスポンスにグループ A 専用メンバーのコメントが漏洩: " \
          "comment=#{comment.inspect}"

        # グループ A 専用メンバーの user_id がグループ B のレスポンスに存在しないことも確認
        date_key = date.iso8601
        date_data = json_b.dig("availabilities", date_key) || {}
        expect(date_data.keys).not_to include(member_only_a.id.to_s),
          "グループ B のレスポンスにグループ A 専用メンバーのデータが存在する: " \
          "user_id=#{member_only_a.id}"
      end
    end
  end
end
