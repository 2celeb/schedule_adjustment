# Google カレンダーキャッシュモデル
# FreeBusy API の結果（予定の有無のみ）をキャッシュ
class CalendarCache < ApplicationRecord
  belongs_to :user
  belongs_to :group

  # キャッシュの有効期限（15分）
  CACHE_TTL = 15.minutes

  # バリデーション
  validates :date, presence: true
  validates :user_id, uniqueness: { scope: [:group_id, :date], message: 'はこのグループ・日付の組み合わせで既にキャッシュが存在します' }

  # キャッシュが古くなっているかどうかを判定
  def stale?
    fetched_at.nil? || fetched_at < CACHE_TTL.ago
  end
end
