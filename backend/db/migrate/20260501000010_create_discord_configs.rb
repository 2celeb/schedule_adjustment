# frozen_string_literal: true

# Discord 設定テーブルの作成
# グループごとの Discord サーバー連携設定を管理する
class CreateDiscordConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :discord_configs do |t|
      t.references :group, foreign_key: true, null: false
      t.string :guild_id                 # Discord サーバーID
      t.string :default_channel_id       # デフォルト通知チャンネル
      t.string :remind_channel_id        # リマインド用チャンネル
      t.timestamps
    end

    add_index :discord_configs, :group_id, unique: true
  end
end
