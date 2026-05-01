# 活動日自動設定ルールモデル
# 週あたりの活動日数、除外曜日、確定タイミング等を管理
class AutoScheduleRule < ApplicationRecord
  belongs_to :group

  # confirm_time は「時刻」（時間帯に依存しない値）として扱う
  # PostgreSQL の time 型はタイムゾーンなしで保存されるが、
  # Rails がデフォルトでタイムゾーン変換を適用してしまうため、
  # 読み書き時に UTC として扱うことで本来の値を保持する
  def confirm_time
    raw = super
    return nil unless raw

    # Rails が適用したタイムゾーン変換を打ち消し、DB の生の値を返す
    raw.utc
  end

  def confirm_time=(value)
    if value.is_a?(String) && value.match?(/\A\d{1,2}:\d{2}\z/)
      # "HH:MM" 形式の文字列を UTC として直接設定
      super(Time.utc(2000, 1, 1, *value.split(":").map(&:to_i)))
    else
      super
    end
  end

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
