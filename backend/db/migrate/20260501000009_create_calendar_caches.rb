# frozen_string_literal: true

# Google カレンダーキャッシュテーブルの作成
# FreeBusy API から取得した予定の有無のみをキャッシュする（プライバシー重視）
class CreateCalendarCaches < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_caches do |t|
      t.references :user, foreign_key: true, null: false
      t.references :group, foreign_key: true, null: false
      t.date :date, null: false
      t.boolean :has_event               # 予定の有無のみ
      t.datetime :fetched_at             # 取得日時（キャッシュ有効期限判定用）
    end

    add_index :calendar_caches, [:user_id, :group_id, :date], unique: true, name: 'idx_calendar_caches_user_group_date'
  end
end
