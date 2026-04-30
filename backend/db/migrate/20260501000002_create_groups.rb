# frozen_string_literal: true

# グループテーブルの作成
# Discord サーバーに対応するグループ情報を管理する
class CreateGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :groups do |t|
      t.string :name, null: false        # グループ名
      t.string :event_name               # イベント名
      t.references :owner, foreign_key: { to_table: :users }, null: false
      t.string :share_token, null: false  # 共通URL用ランダムID（nanoid）
      t.string :timezone, default: 'Asia/Tokyo'
      t.time :default_start_time         # 基本活動開始時間
      t.time :default_end_time           # 基本活動終了時間
      t.integer :threshold_n             # 参加不可人数の閾値
      t.string :threshold_target, default: 'core'  # 閾値対象: core / all
      t.boolean :ad_enabled, default: true  # 広告表示 ON/OFF
      t.string :locale, default: 'ja'    # グループのロケール
      t.timestamps
    end

    add_index :groups, :share_token, unique: true
  end
end
