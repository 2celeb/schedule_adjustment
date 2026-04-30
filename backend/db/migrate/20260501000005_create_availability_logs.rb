# frozen_string_literal: true

# 参加可否変更履歴テーブルの作成
# 追記のみのテーブル（updated_at なし）で変更の抑止力として機能する
class CreateAvailabilityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :availability_logs do |t|
      t.references :availability, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.integer :old_status              # 変更前ステータス
      t.integer :new_status              # 変更後ステータス
      t.text :old_comment                # 変更前コメント
      t.text :new_comment                # 変更後コメント
      t.text :user_agent                 # User-Agent
      t.inet :ip_address                 # IPアドレス（PostgreSQL inet型）
      t.string :geo_region               # IP から推定した地域
      t.datetime :created_at, null: false  # created_at のみ（updated_at 不要）
    end
  end
end
