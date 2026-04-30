# メンバーシップモデル
# ユーザーとグループの中間テーブル。役割（owner/core/sub）を管理
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  # バリデーション
  validates :role, inclusion: { in: %w[owner core sub] }
  validates :user_id, uniqueness: { scope: :group_id, message: 'は既にこのグループに所属しています' }
end
