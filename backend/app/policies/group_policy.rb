# frozen_string_literal: true

# グループ権限ポリシー
# グループ設定変更、URL再生成などの Owner 限定操作を制御する
#
# 使用例:
#   policy = GroupPolicy.new(user, group)
#   policy.update?          # => true/false
#   policy.regenerate_token? # => true/false
class GroupPolicy
  attr_reader :user, :group

  # @param user [User, nil] 操作を行うユーザー
  # @param group [Group] 対象グループ
  def initialize(user, group)
    @user = user
    @group = group
  end

  # グループ設定を更新できるか（Owner のみ）
  def update?
    owner?
  end

  # 共通URLを再生成できるか（Owner のみ）
  def regenerate_token?
    owner?
  end

  private

  # ユーザーが対象グループの Owner かどうかを判定する
  def owner?
    user.present? && group.owner_id == user.id
  end
end
