# frozen_string_literal: true

# 活動日権限ポリシー
# 活動日の追加・変更・削除を Owner のみに制限する
#
# 使用例:
#   policy = EventDayPolicy.new(user, group)
#   policy.create?  # => true/false
#   policy.update?  # => true/false
#   policy.destroy? # => true/false
class EventDayPolicy
  attr_reader :user, :group

  # @param user [User, nil] 操作を行うユーザー
  # @param group [Group] 対象グループ
  def initialize(user, group)
    @user = user
    @group = group
  end

  # 活動日を追加できるか（Owner のみ、要件 5.7）
  def create?
    owner?
  end

  # 活動日を変更できるか（Owner のみ、要件 5.8）
  def update?
    owner?
  end

  # 活動日を削除できるか（Owner のみ、要件 5.8）
  def destroy?
    owner?
  end

  private

  # ユーザーが対象グループの Owner かどうかを判定する
  def owner?
    user.present? && group.owner_id == user.id
  end
end
