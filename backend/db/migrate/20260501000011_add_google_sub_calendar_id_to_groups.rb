# frozen_string_literal: true

# groups テーブルに google_sub_calendar_id カラムを追加
# Owner の Google カレンダーに作成したサブカレンダーの ID を保存する
class AddGoogleSubCalendarIdToGroups < ActiveRecord::Migration[7.2]
  def change
    add_column :groups, :google_sub_calendar_id, :string
  end
end
