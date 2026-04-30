# セッションモデル
# OAuth 識別ユーザー用の Cookie セッション管理
class Session < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # スコープ: 有効なセッションのみ
  scope :active, -> { where('expires_at > ?', Time.current) }

  # セッションが期限切れかどうかを判定
  def expired?
    expires_at <= Time.current
  end
end
