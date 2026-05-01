# frozen_string_literal: true

require 'rails_helper'
require 'rantly'
require 'rantly/property'

# Feature: schedule-management-tool, Property 5: Availability の保存ラウンドトリップ
#
# 任意の有効な status 値（1, 0, -1）とコメント文字列について、
# 保存後に取得すると同じ値が返されることを検証する。
#
# Validates: 要件 3.2, 3.4
RSpec.describe "Property 5: Availability の保存ラウンドトリップ", type: :request do
  # Rantly の property_of ヘルパー
  # rantly/rspec_extensions は require 'rspec' に依存するため直接定義する
  def property_of(&block)
    Rantly::Property.new(block)
  end

  # テスト用ヘルパー: Cookie セッションを設定する
  def set_session_cookie(session)
    cookies[SessionManagement::SESSION_COOKIE_NAME] = session.token
  end

  let!(:owner) { create(:user, display_name: "オーナー") }
  let!(:group) do
    create(:group, :with_times,
           owner: owner,
           name: "プロパティテストグループ",
           locale: "ja")
  end
  let!(:owner_membership) { create(:membership, :owner, user: owner, group: group) }

  let!(:member) { create(:user, display_name: "テストメンバー") }
  let!(:membership) { create(:membership, user: member, group: group) }

  # 未来の日付を生成する（過去日付の権限制御を回避するため）
  # テスト期間中に日付が変わっても問題ないよう、十分先の日付を使用する
  def future_date(offset)
    Date.current + offset.days
  end

  describe "PUT → GET ラウンドトリップ" do
    it "任意の有効な status とコメントについて、保存後に取得すると同じ値が返される" do
      property_of {
        status = choose(1, 0, -1)
        # コメントは × (-1) または △ (0) の場合のみ保存される仕様
        # ○ (1) の場合はコメントが nil になるため、status に応じてコメントを生成
        comment = if status == 1
                    nil
                  else
                    Rantly { sized(range(0, 50)) { string(:alpha) } }
                  end
        # 日付のオフセット（1〜60日先）— 各イテレーションで一意の日付を使用
        date_offset = range(1, 60)
        [status, comment, date_offset]
      }.check(100) do |status, comment, date_offset|
        date = future_date(date_offset)

        # 保存（PUT）
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: member.id,
              availabilities: [
                { date: date.iso8601, status: status, comment: comment }
              ]
            },
            headers: { "X-User-Id" => member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok),
          "PUT が失敗: status=#{status}, comment=#{comment.inspect}, date=#{date.iso8601}, response=#{response.body}"

        put_json = response.parsed_body
        updated = put_json["updated"][0]

        # PUT レスポンスで返される値が入力と一致する
        expect(updated["status"]).to eq(status),
          "PUT レスポンスの status が不一致: expected=#{status}, got=#{updated['status']}"

        expected_comment = (status == -1 || status == 0) ? comment : nil
        expect(updated["comment"]).to eq(expected_comment),
          "PUT レスポンスの comment が不一致: expected=#{expected_comment.inspect}, got=#{updated['comment'].inspect}"

        # 取得（GET）
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok),
          "GET が失敗: date=#{date.iso8601}, response=#{response.body}"

        get_json = response.parsed_body
        date_key = date.iso8601
        user_key = member.id.to_s

        avail_data = get_json.dig("availabilities", date_key, user_key)
        expect(avail_data).to be_present,
          "GET レスポンスに参加可否データが存在しない: date=#{date_key}, user=#{user_key}"

        # GET レスポンスで返される値が保存した値と一致する（ラウンドトリップ）
        expect(avail_data["status"]).to eq(status),
          "GET レスポンスの status が不一致: expected=#{status}, got=#{avail_data['status']}"
        expect(avail_data["comment"]).to eq(expected_comment),
          "GET レスポンスの comment が不一致: expected=#{expected_comment.inspect}, got=#{avail_data['comment'].inspect}"

        # auto_synced は手動保存なので false であること
        expect(avail_data["auto_synced"]).to eq(false),
          "GET レスポンスの auto_synced が false でない"

        # DB の値も直接確認する
        db_record = Availability.find_by(user: member, group: group, date: date)
        expect(db_record).to be_present,
          "DB にレコードが存在しない: date=#{date.iso8601}"
        expect(db_record.status).to eq(status),
          "DB の status が不一致: expected=#{status}, got=#{db_record.status}"
        expect(db_record.comment).to eq(expected_comment),
          "DB の comment が不一致: expected=#{expected_comment.inspect}, got=#{db_record.comment.inspect}"
      end
    end

    it "同じ日付に対して status を変更しても、最新の値が正しく取得される（冪等性）" do
      property_of {
        old_status = choose(1, 0, -1)
        new_status = choose(1, 0, -1)
        comment = if new_status == 1
                    nil
                  else
                    Rantly { sized(range(0, 30)) { string(:alpha) } }
                  end
        date_offset = range(1, 60)
        [old_status, new_status, comment, date_offset]
      }.check(100) do |old_status, new_status, comment, date_offset|
        date = future_date(date_offset)

        # 1回目の保存
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: member.id,
              availabilities: [
                { date: date.iso8601, status: old_status, comment: nil }
              ]
            },
            headers: { "X-User-Id" => member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok),
          "1回目の PUT が失敗: old_status=#{old_status}, date=#{date.iso8601}"

        # 2回目の保存（上書き）
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: member.id,
              availabilities: [
                { date: date.iso8601, status: new_status, comment: comment }
              ]
            },
            headers: { "X-User-Id" => member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok),
          "2回目の PUT が失敗: new_status=#{new_status}, date=#{date.iso8601}"

        # 取得して最新の値が返されることを確認
        month_str = date.strftime("%Y-%m")
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: month_str }

        expect(response).to have_http_status(:ok)

        get_json = response.parsed_body
        avail_data = get_json.dig("availabilities", date.iso8601, member.id.to_s)

        expected_comment = (new_status == -1 || new_status == 0) ? comment : nil

        expect(avail_data["status"]).to eq(new_status),
          "上書き後の status が不一致: expected=#{new_status}, got=#{avail_data['status']}, old=#{old_status}"
        expect(avail_data["comment"]).to eq(expected_comment),
          "上書き後の comment が不一致: expected=#{expected_comment.inspect}, got=#{avail_data['comment'].inspect}"

        # DB にレコードが1件のみ存在する（重複なし）
        db_count = Availability.where(user: member, group: group, date: date).count
        expect(db_count).to eq(1),
          "DB のレコード数が1でない: count=#{db_count}, date=#{date.iso8601}"
      end
    end

    it "コメントの保存制御: ○ (1) の場合はコメントが常に nil になる" do
      property_of {
        comment = Rantly { sized(range(1, 50)) { string(:alpha) } }
        date_offset = range(1, 60)
        [comment, date_offset]
      }.check(100) do |comment, date_offset|
        date = future_date(date_offset)

        # status=1（○）でコメント付きで保存
        put "/api/groups/#{group.share_token}/availabilities",
            params: {
              user_id: member.id,
              availabilities: [
                { date: date.iso8601, status: 1, comment: comment }
              ]
            },
            headers: { "X-User-Id" => member.id.to_s },
            as: :json

        expect(response).to have_http_status(:ok)

        # PUT レスポンスでコメントが nil であること
        put_json = response.parsed_body
        expect(put_json["updated"][0]["comment"]).to be_nil,
          "status=1 なのにコメントが保存された: comment=#{comment.inspect}"

        # GET でもコメントが nil であること
        get "/api/groups/#{group.share_token}/availabilities",
            params: { month: date.strftime("%Y-%m") }

        get_json = response.parsed_body
        avail_data = get_json.dig("availabilities", date.iso8601, member.id.to_s)
        expect(avail_data["comment"]).to be_nil,
          "GET レスポンスで status=1 なのにコメントが返された"

        # DB でもコメントが nil であること
        db_record = Availability.find_by(user: member, group: group, date: date)
        expect(db_record.comment).to be_nil,
          "DB で status=1 なのにコメントが保存されている"
      end
    end
  end
end
