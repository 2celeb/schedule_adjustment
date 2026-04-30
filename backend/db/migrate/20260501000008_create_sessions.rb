# frozen_string_literal: true

# セッションテーブルの作成
# OAuth 識別ユーザーのセッション管理（Cookie ベース）
class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, foreign_key: true, null: false
      t.string :token, null: false       # セッショントークン
      t.datetime :expires_at, null: false  # 有効期限
      t.text :user_agent                 # User-Agent
      t.inet :ip_address                 # IPアドレス
      t.datetime :created_at, null: false
    end

    add_index :sessions, :token, unique: true
  end
end
