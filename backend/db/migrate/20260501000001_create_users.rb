# frozen_string_literal: true

# ユーザーテーブルの作成
# Discord メンバーから自動登録されるユーザー情報を管理する
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :discord_user_id          # Discord ユーザーID
      t.string :discord_screen_name      # Discord スクリーン名
      t.string :display_name             # 表示名（変更可能）
      t.string :google_account_id        # Google アカウントID（連携時に設定）
      t.text :google_oauth_token         # Google OAuth トークン（暗号化）
      t.string :google_calendar_scope    # 連携パターン: none / freebusy / full
      t.boolean :auth_locked, default: false  # true = OAuth 識別（🔒）
      t.string :locale, default: 'ja'    # ロケール設定
      t.boolean :anonymized, default: false   # 退会時に true
      t.timestamps
    end

    add_index :users, :discord_user_id, unique: true
    add_index :users, :google_account_id, unique: true
  end
end
