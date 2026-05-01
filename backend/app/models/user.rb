# ユーザーモデル
# Discord メンバーから自動登録され、Google OAuth 連携も可能
class User < ApplicationRecord
  # Google OAuth トークンの暗号化
  encrypts :google_oauth_token

  # リレーション
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :owned_groups, class_name: 'Group', foreign_key: :owner_id, dependent: :restrict_with_error, inverse_of: :owner
  has_many :availabilities, dependent: :destroy
  has_many :availability_logs, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :calendar_caches, class_name: 'CalendarCache', dependent: :destroy

  # バリデーション
  validates :discord_user_id, uniqueness: true, allow_nil: true
  validates :google_account_id, uniqueness: true, allow_nil: true
  validates :locale, inclusion: { in: %w[ja en] }
end
