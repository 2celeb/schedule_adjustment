# 参加可否モデル
# メンバーの各日の参加可否状態（○/△/×/未入力）を管理
class Availability < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_many :availability_logs, dependent: :destroy

  # バリデーション
  validates :date, presence: true
  validates :status, inclusion: { in: [1, 0, -1] }, allow_nil: true
  validates :user_id, uniqueness: { scope: [:group_id, :date], message: 'はこのグループ・日付の組み合わせで既に登録されています' }
end
