# frozen_string_literal: true

# 退会メンバー匿名化サービス
#
# メンバーの退会処理を行い、個人情報を匿名化する。
# - display_name を「退会済みメンバーX」形式に匿名化
# - anonymized フラグを true に設定
# - 個人情報（google_oauth_token、google_account_id、discord_user_id）を即時削除
#   ※ ただし他のグループに所属している場合は discord_user_id を保持する
# - calendar_caches の削除（対象グループ分のみ）
# - availabilities レコードは削除せず匿名化状態で無期限保持
# - セッションを全て無効化
#
# 使用例:
#   result = MemberAnonymizer.new(user, group).call
#   result[:success]  # => true
#   result[:user]     # => 匿名化されたユーザー
#
# @see 要件 10.4, 10.5
class MemberAnonymizer
  # @param user [User] 退会対象のユーザー
  # @param group [Group] 対象グループ
  def initialize(user, group)
    @user = user
    @group = group
  end

  # 退会処理を実行する
  #
  # トランザクション内で以下を実行:
  # 1. display_name を匿名化形式に変更
  # 2. anonymized フラグを true に設定
  # 3. 個人情報を null に設定（他グループ所属時は discord_user_id を保持）
  # 4. auth_locked を false に設定
  # 5. google_calendar_scope を null に設定
  # 6. calendar_caches レコードを削除（対象グループ分のみ）
  # 7. セッションを全て無効化
  # 8. メンバーシップを削除
  #
  # availabilities レコードは削除せず、匿名化状態で無期限保持する。
  #
  # @return [Hash] { success: Boolean, user: User, error: String? }
  def call
    return already_anonymized_error if @user.anonymized?

    membership = @group.memberships.find_by(user: @user)
    return membership_not_found_error unless membership

    return owner_cannot_withdraw_error if membership.role == "owner"

    ActiveRecord::Base.transaction do
      anonymize_user!
      delete_calendar_caches!
      invalidate_sessions!
      membership.destroy!
    end

    { success: true, user: @user.reload }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: e.message }
  end

  private

  # ユーザー情報を匿名化する
  # 他のグループに所属している場合は discord_user_id を保持する
  def anonymize_user!
    anonymous_name = generate_anonymous_name
    has_other_groups = other_group_memberships_exist?

    attrs = {
      display_name: anonymous_name,
      anonymized: true,
      auth_locked: false,
      google_oauth_token: nil,
      google_account_id: nil,
      google_calendar_scope: nil,
      discord_screen_name: nil
    }

    # 他のグループに所属していない場合のみ discord_user_id を削除
    attrs[:discord_user_id] = nil unless has_other_groups

    @user.update!(attrs)
  end

  # 対象グループ以外のメンバーシップが存在するかを判定する
  #
  # @return [Boolean]
  def other_group_memberships_exist?
    @user.memberships.where.not(group: @group).exists?
  end

  # 匿名化された表示名を生成する
  # グローバルで一意になるように連番を付与する
  #
  # @return [String] 「退会済みメンバーX」形式の表示名
  def generate_anonymous_name
    # 既存の匿名化メンバーの最大番号を取得
    existing_numbers = User
      .where(anonymized: true)
      .where("display_name LIKE ?", "退会済みメンバー%")
      .pluck(:display_name)
      .filter_map { |name| name.match(/退会済みメンバー(\d+)/)&.captures&.first&.to_i }

    next_number = existing_numbers.any? ? existing_numbers.max + 1 : 1
    "退会済みメンバー#{next_number}"
  end

  # calendar_caches レコードを削除する（対象グループ分のみ）
  def delete_calendar_caches!
    @user.calendar_caches.where(group: @group).delete_all
  end

  # セッションを全て無効化する
  def invalidate_sessions!
    @user.sessions.delete_all
  end

  # 既に匿名化済みの場合のエラー
  def already_anonymized_error
    { success: false, error: "このユーザーは既に退会処理済みです。" }
  end

  # メンバーシップが見つからない場合のエラー
  def membership_not_found_error
    { success: false, error: "このユーザーはグループのメンバーではありません。" }
  end

  # Owner は退会できない場合のエラー
  def owner_cannot_withdraw_error
    { success: false, error: "グループのOwnerは退会できません。" }
  end
end
