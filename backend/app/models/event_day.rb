# 活動日モデル
# Owner が確定した活動日。開始・終了時間を持つ
class EventDay < ApplicationRecord
  belongs_to :group

  # バリデーション
  validates :date, presence: true
  validates :group_id, uniqueness: { scope: :date, message: 'はこの日付で既に活動日が登録されています' }
end
