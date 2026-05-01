# frozen_string_literal: true

# 参加可否集計サービス
#
# グループの参加可否データを日付ごとに集計し、
# Threshold_N に基づく警告フラグを算出する。
#
# 使用例:
#   aggregator = AvailabilityAggregator.new(group, date_range)
#   summary = aggregator.call
#   # => {
#   #   "2025-01-06" => { ok: 5, maybe: 2, ng: 1, none: 2, warning: false },
#   #   "2025-01-07" => { ok: 3, maybe: 1, ng: 4, none: 2, warning: true }
#   # }
class AvailabilityAggregator
  # @param group [Group] 対象グループ
  # @param date_range [Range<Date>] 集計対象の日付範囲
  def initialize(group, date_range)
    @group = group
    @date_range = date_range
  end

  # 集計を実行する
  #
  # @return [Hash] 日付文字列をキー、集計結果ハッシュを値とするハッシュ
  #   各集計結果は { ok:, maybe:, ng:, none:, warning: } を含む
  def call
    memberships = load_memberships
    availabilities = load_availabilities

    total_members = memberships.size
    core_member_ids = extract_core_member_ids(memberships)
    avail_by_date = availabilities.group_by(&:date)

    summary = {}
    @date_range.each do |date|
      day_avails = avail_by_date[date] || []
      counts = count_statuses(day_avails, total_members)
      warning = evaluate_warning(day_avails, core_member_ids)
      summary[date.iso8601] = counts.merge(warning: warning)
    end

    summary
  end

  private

  # グループのメンバーシップを取得する
  #
  # @return [ActiveRecord::Relation<Membership>]
  def load_memberships
    @group.memberships.includes(:user)
  end

  # 指定期間の参加可否データを取得する
  #
  # @return [ActiveRecord::Relation<Availability>]
  def load_availabilities
    @group.availabilities.where(date: @date_range)
  end

  # Core_Member のユーザー ID 一覧を抽出する
  # Owner も Core_Member として扱う（Threshold_N 判定の対象）
  #
  # @param memberships [ActiveRecord::Relation<Membership>]
  # @return [Set<Integer>] Core_Member のユーザー ID の集合
  def extract_core_member_ids(memberships)
    memberships
      .select { |m| m.role == "core" || m.role == "owner" }
      .map(&:user_id)
      .to_set
  end

  # 日付ごとの ○/△/×/− の人数を集計する
  #
  # @param day_avails [Array<Availability>] 当日の参加可否データ
  # @param total_members [Integer] グループの総メンバー数
  # @return [Hash] { ok:, maybe:, ng:, none: }
  def count_statuses(day_avails, total_members)
    ok = 0
    maybe = 0
    ng = 0

    day_avails.each do |a|
      case a.status
      when 1  then ok += 1
      when 0  then maybe += 1
      when -1 then ng += 1
      # nil（未入力）は none に含まれるため何もしない
      end
    end

    none = total_members - ok - maybe - ng

    { ok: ok, maybe: maybe, ng: ng, none: none }
  end

  # Threshold_N に基づく警告フラグを判定する
  #
  # threshold_n が未設定（nil）の場合は常に false を返す。
  # threshold_target が "core" の場合は Core_Member（+ Owner）のみの×人数を対象とし、
  # "all" の場合は全メンバーの×人数を対象とする。
  #
  # @param day_avails [Array<Availability>] 当日の参加可否データ
  # @param core_member_ids [Set<Integer>] Core_Member のユーザー ID の集合
  # @return [Boolean] 警告フラグ
  def evaluate_warning(day_avails, core_member_ids)
    return false if @group.threshold_n.nil?

    ng_count = if @group.threshold_target == "all"
                 day_avails.count { |a| a.status == -1 }
               else
                 # デフォルト: Core_Member のみ
                 day_avails.count { |a| a.status == -1 && core_member_ids.include?(a.user_id) }
               end

    ng_count >= @group.threshold_n
  end
end
