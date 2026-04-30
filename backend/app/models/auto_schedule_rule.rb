# 活動日自動設定ルールモデル
# 週あたりの活動日数、除外曜日、確定タイミング等を管理
class AutoScheduleRule < ApplicationRecord
  belongs_to :group

  # バリデーション
  validates :max_days_per_week, numericality: { in: 1..7 }, allow_nil: true
  validates :min_days_per_week, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :week_start_day, inclusion: { in: 0..6 }
  validates :confirm_days_before, numericality: { greater_than: 0 }
  validate :min_not_greater_than_max

  private

  # 最低活動日数が最大活動日数を超えないことを検証
  def min_not_greater_than_max
    return if min_days_per_week.nil? || max_days_per_week.nil?

    if min_days_per_week > max_days_per_week
      errors.add(:min_days_per_week, 'は最大活動日数以下にしてください')
    end
  end
end
