# frozen_string_literal: true

module Api
  module Internal
    # 内部 API: 通知コントローラー
    # Rails → Discord Bot への通知トリガーを提供する
    # Bot トークン認証を使用する
    #
    # エンドポイント:
    # - POST /api/internal/notifications/remind — リマインド送信トリガー（Bot トークン認証）
    # - POST /api/internal/notifications/daily — 当日通知トリガー（Bot トークン認証）
    #
    # 要件: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7
    class NotificationsController < BaseController
      # POST /api/internal/notifications/remind
      # リマインド送信をトリガーする
      #
      # パラメータ:
      #   group_id: グループ ID（任意。指定しない場合は全グループ対象）
      def remind
        group_id = params[:group_id]

        if group_id.present?
          group = Group.find_by(id: group_id)
          unless group
            render json: {
              error: {
                code: "NOT_FOUND",
                message: "グループが見つかりません。"
              }
            }, status: :not_found
            return
          end
        end

        # リマインドジョブを非同期実行
        RemindJob.perform_later(group_id&.to_i)

        render json: {
          message: "リマインドジョブをキューに追加しました。",
          group_id: group_id
        }, status: :accepted
      end

      # POST /api/internal/notifications/daily
      # 活動日当日通知をトリガーする
      #
      # パラメータ:
      #   group_id: グループ ID（任意。指定しない場合は全グループ対象）
      def daily
        group_id = params[:group_id]

        if group_id.present?
          group = Group.find_by(id: group_id)
          unless group
            render json: {
              error: {
                code: "NOT_FOUND",
                message: "グループが見つかりません。"
              }
            }, status: :not_found
            return
          end
        end

        # 当日通知ジョブを非同期実行
        DailyNotifyJob.perform_later(group_id&.to_i)

        render json: {
          message: "当日通知ジョブをキューに追加しました。",
          group_id: group_id
        }, status: :accepted
      end
    end
  end
end
