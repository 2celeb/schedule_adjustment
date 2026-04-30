# frozen_string_literal: true

# 活動日テーブルの作成
# グループの活動日（自動生成・手動設定）を管理する
class CreateEventDays < ActiveRecord::Migration[7.1]
  def change
    create_table :event_days do |t|
      t.references :group, foreign_key: true, null: false
      t.date :date, null: false
      t.time :start_time                 # 個別の活動開始時間（null=グループデフォルト）
      t.time :end_time                   # 個別の活動終了時間
      t.boolean :auto_generated, default: false  # 自動生成か手動設定か
      t.boolean :confirmed, default: false       # 確定済みか
      t.datetime :confirmed_at           # 確定日時
      t.timestamps
    end

    add_index :event_days, [:group_id, :date], unique: true
  end
end
