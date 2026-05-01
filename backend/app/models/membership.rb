# メンバーシップモデル
# ユーザーとグループの中間テーブル。役割（owner/core/sub）を管理
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  # バリデーション
  validates :role, inclusion: { in: %w[owner core sub] }
  validates :user_id, uniqueness: { scope: :group_id, message: 'は既にこのグループに所属しています' }
  validate :group_member_limit, on: :create

  private

  # グループのメンバー上限チェック
  # 新規作成時にグループのメンバー数が上限に達している場合はエラー
  def group_member_limit
    return unless group

    if group.member_limit_reached?
      errors.add(:base, "グループのメンバー数が上限（#{Group::MAX_MEMBERS}名）に達しています。")
    end
  end
end
