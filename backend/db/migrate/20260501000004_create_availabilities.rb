# frozen_string_literal: true

# 参加可否テーブルの作成
# メンバーの日ごとの参加可否状態を管理する
class CreateAvailabilities < ActiveRecord::Migration[7.1]
  def change
    create_table :availabilities do |t|
      t.references :user, foreign_key: true, null: false
      t.references :group, foreign_key: true, null: false
      t.date :date, null: false          # 対象日付
      t.integer :status                  # 1=○, 0=△, -1=×, null=未入力
      t.text :comment                    # コメント
      t.boolean :auto_synced, default: false  # Google カレンダーから自動設定
      t.timestamps
    end

    add_index :availabilities, [:user_id, :group_id, :date], unique: true, name: 'idx_availabilities_user_group_date'
  end
end
