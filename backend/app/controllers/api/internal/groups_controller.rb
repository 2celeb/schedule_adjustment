# frozen_string_literal: true

module Api
  module Internal
    # 内部 API: グループ管理コントローラー
    # Discord Bot からのグループ作成・メンバー同期・週次入力状況取得を提供する
    #
    # エンドポイント:
    # - POST /api/internal/groups — グループ初回作成（Bot トークン認証）
    # - POST /api/internal/groups/:id/sync_members — メンバー同期（Bot トークン認証）
    # - GET /api/internal/groups/:id/weekly_status — 週次入力状況取得（Bot トークン認証）
    class GroupsController < BaseController
      before_action :set_group, only: [:sync_members, :weekly_status]

      # POST /api/internal/groups
      # Discord Bot からグループを初回作成する
      #
      # パラメータ:
      #   guild_id: Discord サーバー ID
      #   name: グループ名（デフォルト: Discord サーバー名）
      #   owner_discord_user_id: Owner の Discord ユーザー ID
      #   owner_discord_screen_name: Owner の Discord スクリーン名
      #   default_start_time: 基本活動開始時間（任意）
      #   default_end_time: 基本活動終了時間（任意）
      #   locale: ロケール（任意、デフォルト: ja）
      def create
        guild_id = params[:guild_id]
        owner_discord_user_id = params[:owner_discord_user_id]

        # 必須パラメータの検証
        if guild_id.blank? || owner_discord_user_id.blank?
          render json: {
            error: {
              code: "VALIDATION_ERROR",
              message: "guild_id と owner_discord_user_id は必須です。"
            }
          }, status: :bad_request
          return
        end

        # 同じ guild_id のグループが既に存在する場合は既存グループを返す
        existing_config = DiscordConfig.find_by(guild_id: guild_id)
        if existing_config
          render json: { group: serialize_group(existing_config.group) }, status: :ok
          return
        end

        ActiveRecord::Base.transaction do
          # Owner ユーザーの取得または作成
          owner = find_or_create_discord_user(
            owner_discord_user_id,
            params[:owner_discord_screen_name] || "Owner"
          )

          # グループの作成
          group = Group.create!(
            name: params[:name].presence || "新規グループ",
            event_name: "#{params[:name].presence || '新規グループ'}の活動",
            owner: owner,
            default_start_time: params[:default_start_time],
            default_end_time: params[:default_end_time],
            locale: params[:locale].presence || "ja"
          )

          # Owner のメンバーシップを作成
          Membership.create!(
            user: owner,
            group: group,
            role: "owner"
          )

          # Discord 設定の作成
          DiscordConfig.create!(
            group: group,
            guild_id: guild_id,
            default_channel_id: params[:default_channel_id]
          )

          render json: { group: serialize_group(group) }, status: :created
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "グループの作成に失敗しました。",
            details: e.record.errors.map { |err| { field: err.attribute.to_s, message: err.message } }
          }
        }, status: :unprocessable_entity
      end

      # POST /api/internal/groups/:id/sync_members
      # Discord メンバーリストからメンバーを一括登録・更新する
      #
      # パラメータ:
      #   members: メンバー情報の配列
      #     - discord_user_id: Discord ユーザー ID
      #     - discord_screen_name: Discord スクリーン名
      #     - display_name: 表示名（任意、デフォルト: discord_screen_name）
      def sync_members
        members_params = params[:members]

        unless members_params.is_a?(Array)
          render json: {
            error: {
              code: "VALIDATION_ERROR",
              message: "members パラメータは配列で指定してください。"
            }
          }, status: :bad_request
          return
        end

        results = { added: [], updated: [], skipped: [], errors: [] }

        ActiveRecord::Base.transaction do
          members_params.each do |member_data|
            discord_user_id = member_data[:discord_user_id]

            if discord_user_id.blank?
              results[:errors] << { discord_user_id: nil, message: "discord_user_id は必須です。" }
              next
            end

            # Owner の discord_user_id と一致する場合はスキップ（既に登録済み）
            if @group.owner.discord_user_id == discord_user_id
              results[:skipped] << { discord_user_id: discord_user_id, reason: "owner" }
              next
            end

            # メンバー上限チェック
            if @group.member_limit_reached?
              results[:errors] << {
                discord_user_id: discord_user_id,
                message: "グループのメンバー数が上限（#{Group::MAX_MEMBERS}名）に達しています。"
              }
              next
            end

            # ユーザーの取得または作成
            user = find_or_create_discord_user(
              discord_user_id,
              member_data[:discord_screen_name] || discord_user_id
            )

            # 既存メンバーシップの確認
            membership = Membership.find_by(user: user, group: @group)

            if membership
              # 既存メンバー: Discord スクリーン名を更新
              if member_data[:discord_screen_name].present?
                user.update!(discord_screen_name: member_data[:discord_screen_name])
              end
              results[:updated] << { discord_user_id: discord_user_id, user_id: user.id }
            else
              # 新規メンバー: メンバーシップを作成
              display_name = member_data[:display_name].presence || member_data[:discord_screen_name] || discord_user_id
              user.update!(display_name: display_name) unless user.display_name.present?

              Membership.create!(
                user: user,
                group: @group,
                role: "sub"
              )
              results[:added] << { discord_user_id: discord_user_id, user_id: user.id }
            end
          end
        end

        render json: {
          group_id: @group.id,
          results: results
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "メンバー同期に失敗しました。",
            details: e.record.errors.map { |err| { field: err.attribute.to_s, message: err.message } }
          }
        }, status: :unprocessable_entity
      end

      # GET /api/internal/groups/:id/weekly_status
      # 今週の予定入力状況を取得する
      #
      # レスポンス:
      #   group: グループ情報
      #   week_start: 週の開始日
      #   week_end: 週の終了日
      #   members: メンバーごとの入力状況
      def weekly_status
        # 週の範囲を計算（グループの week_start_day を考慮）
        rule = @group.auto_schedule_rule
        week_start_day = rule&.week_start_day || 1 # デフォルト: 月曜日

        today = Date.current
        week_start = calculate_week_start(today, week_start_day)
        week_end = week_start + 6.days

        # メンバーと参加可否を取得
        memberships = @group.memberships.includes(:user).order(:created_at)
        availabilities = @group.availabilities
          .where(date: week_start..week_end)
          .index_by { |a| [a.user_id, a.date] }

        members_status = memberships.map do |membership|
          user = membership.user
          dates = (week_start..week_end).map do |date|
            availability = availabilities[[user.id, date]]
            {
              date: date.to_s,
              status: availability&.status,
              filled: !availability&.status.nil?
            }
          end

          filled_count = dates.count { |d| d[:filled] }

          {
            user_id: user.id,
            display_name: user.display_name,
            discord_user_id: user.discord_user_id,
            role: membership.role,
            dates: dates,
            filled_count: filled_count,
            total_days: 7
          }
        end

        render json: {
          group: {
            id: @group.id,
            name: @group.name,
            share_token: @group.share_token
          },
          week_start: week_start.to_s,
          week_end: week_end.to_s,
          members: members_status
        }
      end

      private

      # ID からグループを取得する
      def set_group
        @group = Group.find_by(id: params[:id])
        return if @group

        render json: {
          error: {
            code: "NOT_FOUND",
            message: "グループが見つかりません。"
          }
        }, status: :not_found
      end

      # Discord ユーザー ID からユーザーを取得または作成する
      def find_or_create_discord_user(discord_user_id, discord_screen_name)
        user = User.find_by(discord_user_id: discord_user_id)
        return user if user

        User.create!(
          discord_user_id: discord_user_id,
          discord_screen_name: discord_screen_name,
          display_name: discord_screen_name,
          locale: "ja"
        )
      end

      # 今週の開始日を計算する
      # week_start_day: 0=日曜、1=月曜、...、6=土曜
      def calculate_week_start(today, week_start_day)
        current_wday = today.wday
        days_since_start = (current_wday - week_start_day) % 7
        today - days_since_start.days
      end

      # グループ情報のシリアライズ
      def serialize_group(group)
        {
          id: group.id,
          name: group.name,
          event_name: group.event_name,
          owner_id: group.owner_id,
          share_token: group.share_token,
          timezone: group.timezone,
          default_start_time: group.default_start_time&.strftime("%H:%M"),
          default_end_time: group.default_end_time&.strftime("%H:%M"),
          locale: group.locale,
          created_at: group.created_at,
          updated_at: group.updated_at
        }
      end
    end
  end
end
