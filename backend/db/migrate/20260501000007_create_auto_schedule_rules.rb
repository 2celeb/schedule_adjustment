# frozen_string_literal: true

# 活動日自動設定ルールテーブルの作成
# グループごとの自動確定ルールを管理する
class CreateAutoScheduleRules < ActiveRecord::Migration[7.1]
  def change
    create_table :auto_schedule_rules do |t|
      t.references :group, foreign_key: true, null: false
      t.integer :max_days_per_week       # 週の最大活動日数
      t.integer :min_days_per_week       # 週の最低活動日数
      t.integer :deprioritized_days, array: true, default: []  # 優先度を下げる曜日（PostgreSQL integer[]）
      t.integer :excluded_days, array: true, default: []       # 除外曜日（PostgreSQL integer[]）
      t.integer :week_start_day, default: 1     # 週の始まり（0=日〜6=土）
      t.integer :confirm_days_before, default: 3  # 確定日（週の始まりのN日前）
      t.integer :remind_days_before_confirm, default: 2  # リマインド開始日
      t.time :confirm_time, default: '21:00'    # 確定時刻
      t.integer :activity_notify_hours_before, default: 8  # 当日通知（開始N時間前）
      t.string :activity_notify_channel_id      # 当日通知チャンネル
      t.text :activity_notify_message           # 当日通知メッセージ
      t.timestamps
    end
  end
end
