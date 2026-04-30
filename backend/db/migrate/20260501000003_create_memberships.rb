# frozen_string_literal: true

# メンバーシップテーブルの作成
# ユーザーとグループの多対多の関連を管理する
class CreateMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :memberships do |t|
      t.references :user, foreign_key: true, null: false
      t.references :group, foreign_key: true, null: false
      t.string :role, default: 'sub'     # owner / core / sub
      t.timestamps
    end

    add_index :memberships, [:user_id, :group_id], unique: true
  end
end
