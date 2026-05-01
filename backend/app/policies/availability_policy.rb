# frozen_string_literal: true

# 参加可否権限ポリシー
# auth_locked ユーザーの Cookie 必須チェック、過去日付の変更制御を行う
#
# 使用例:
#   policy = AvailabilityPolicy.new(user, group)
#   policy.update?(date: Date.yesterday, authenticated_via_cookie: false)
class AvailabilityPolicy
  attr_reader :user, :group

  # @param user [User, nil] 操作を行うユーザー
  # @param group [Group] 対象グループ
  def initialize(user, group)
    @user = user
    @group = group
  end

  # 参加可否を更新できるか
  #
  # @param date [Date] 対象日付
  # @param authenticated_via_cookie [Boolean] Cookie セッションで認証されているか
  # @return [Boolean] 更新可能かどうか
  def update?(date:, authenticated_via_cookie: false)
    return false if user.blank?

    # auth_locked ユーザーは Cookie 認証必須（要件 1.5）
    return false if user.auth_locked? && !authenticated_via_cookie

    # 過去日付は Owner のみ変更可（要件 3.7, 3.8）
    return false if past_date?(date) && !owner?

    true
  end

  private

  # 対象日付が過去かどうかを判定する
  def past_date?(date)
    date < Date.current
  end

  # ユーザーが対象グループの Owner かどうかを判定する
  def owner?
    group.owner_id == user.id
  end
end
