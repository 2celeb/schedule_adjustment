# グループモデル
# Discord サーバーに対応し、メンバーのスケジュール管理を行う
class Group < ApplicationRecord
  # メンバー上限
  MAX_MEMBERS = 20

  # コールバック: share_token の自動生成
  before_validation :generate_share_token, on: :create

  # リレーション
  belongs_to :owner, class_name: 'User', inverse_of: :owned_groups
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :availabilities, dependent: :destroy
  has_many :event_days, dependent: :destroy
  has_one :auto_schedule_rule, dependent: :destroy
  has_one :discord_config, dependent: :destroy
  has_many :calendar_caches, dependent: :destroy

  # バリデーション
  validates :name, presence: true
  validates :share_token, presence: true, uniqueness: true
  validates :threshold_target, inclusion: { in: %w[core all] }, allow_nil: true
  validates :locale, inclusion: { in: %w[ja en] }

  # メンバー上限に達しているかを判定する
  def member_limit_reached?
    memberships.count >= MAX_MEMBERS
  end

  private

  # nanoid で share_token を自動生成
  def generate_share_token
    self.share_token ||= Nanoid.generate(size: 21)
  end
end
