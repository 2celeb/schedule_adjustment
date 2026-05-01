# frozen_string_literal: true

# 活動日自動確定サービス
#
# 自動確定ルール（AutoScheduleRule）に基づいて、対象週の活動日を決定するコアロジック。
# 当該週の参加可否データを集計し、ルールの制約を満たす活動日候補を選定する。
#
# 制約充足:
# - 週あたり活動日数が max_days_per_week 以下
# - 週あたり活動日数が min_days_per_week 以上
# - excluded_days に含まれる曜日は min 未達時を除き活動日にしない
# - deprioritized_days に含まれる曜日は後回し
#
# 確定日計算:
# - week_start_day の confirm_days_before 日前
#
# 使用例:
#   service = AutoScheduleService.new(group)
#   event_days = service.generate_for_week(target_date)
#   # => [EventDay, EventDay, ...]
#
# 要件: 5.1, 5.6
class AutoScheduleService
  # @param group [Group] 対象グループ
  def initialize(group)
    @group = group
    @rule = group.auto_schedule_rule
  end

  # 指定日を含む週の活動日を自動生成する
  #
  # @param target_date [Date] 対象日（この日を含む週が対象）
  # @return [Array<EventDay>] 生成された活動日の配列
  def generate_for_week(target_date)
    return [] unless @rule

    week_dates = week_dates_for(target_date)
    scored_dates = score_dates(week_dates)
    selected_dates = select_dates(scored_dates)

    create_event_days(selected_dates)
  end

  # 指定日を含む週の確定日を計算する
  #
  # @param target_date [Date] 対象日
  # @return [Date] 確定日
  def confirm_date_for(target_date)
    return nil unless @rule

    week_start = next_week_start(target_date)
    week_start - @rule.confirm_days_before.days
  end

  # 次の週の開始日を計算する
  #
  # @param from_date [Date] 基準日
  # @return [Date] 次の週の開始日（week_start_day に対応する曜日）
  def next_week_start(from_date)
    return nil unless @rule

    wday = @rule.week_start_day
    # from_date 以降で最初の week_start_day を見つける
    date = from_date
    date += 1.day until date.wday == wday
    date
  end

  private

  # 対象週の日付一覧を取得する
  #
  # @param target_date [Date] 対象日
  # @return [Array<Date>] 週の7日間の日付配列
  def week_dates_for(target_date)
    start_date = find_week_start(target_date)
    (0..6).map { |i| start_date + i.days }
  end

  # 対象日を含む週の開始日を見つける
  #
  # @param date [Date] 対象日
  # @return [Date] 週の開始日
  def find_week_start(date)
    wday = @rule.week_start_day
    current = date
    current -= 1.day until current.wday == wday
    current
  end

  # 各日付にスコアを付与する
  # スコアが高いほど活動日として適している
  #
  # スコア計算:
  # - ○（参加可能）の人数をベーススコアとする
  # - △（未定）は 0.5 として加算
  # - ×（参加不可）は -1 として減算
  # - excluded_days は -1000（事実上除外）
  # - deprioritized_days は -10（後回し）
  #
  # @param dates [Array<Date>] 対象日付の配列
  # @return [Array<Hash>] [{ date:, score:, excluded:, deprioritized: }, ...]
  def score_dates(dates)
    availabilities = load_availabilities(dates)
    avail_by_date = availabilities.group_by(&:date)

    excluded = Set.new(@rule.excluded_days || [])
    deprioritized = Set.new(@rule.deprioritized_days || [])

    dates.map do |date|
      day_avails = avail_by_date[date] || []
      is_excluded = excluded.include?(date.wday)
      is_deprioritized = deprioritized.include?(date.wday)

      base_score = calculate_base_score(day_avails)
      penalty = 0
      penalty -= 1000 if is_excluded
      penalty -= 10 if is_deprioritized

      {
        date: date,
        score: base_score + penalty,
        excluded: is_excluded,
        deprioritized: is_deprioritized
      }
    end
  end

  # 参加可否データからベーススコアを計算する
  #
  # @param day_avails [Array<Availability>] 当日の参加可否データ
  # @return [Float] ベーススコア
  def calculate_base_score(day_avails)
    score = 0.0
    day_avails.each do |a|
      case a.status
      when 1  then score += 1.0   # ○
      when 0  then score += 0.5   # △
      when -1 then score -= 1.0   # ×
      # nil（未入力）はスコアに影響しない
      end
    end
    score
  end

  # スコアに基づいて活動日を選定する
  #
  # 制約充足ロジック:
  # 1. スコア降順でソート
  # 2. excluded でない日から max_days_per_week 個まで選択
  # 3. min_days_per_week に満たない場合は excluded の日も追加
  #
  # @param scored_dates [Array<Hash>] スコア付き日付の配列
  # @return [Array<Date>] 選定された日付の配列
  def select_dates(scored_dates)
    max_days = @rule.max_days_per_week || 7
    min_days = @rule.min_days_per_week || 0

    # スコア降順でソート（同スコアの場合は日付順）
    sorted = scored_dates.sort_by { |d| [-d[:score], d[:date]] }

    selected = []

    # Phase 1: excluded でない日から選択
    sorted.each do |entry|
      break if selected.size >= max_days

      next if entry[:excluded]

      selected << entry[:date]
    end

    # Phase 2: min 未達の場合は excluded の日も追加（スコア順）
    if selected.size < min_days
      sorted.each do |entry|
        break if selected.size >= min_days

        next unless entry[:excluded]
        next if selected.include?(entry[:date])

        selected << entry[:date]
      end
    end

    # max を超えないように制限
    selected = selected.first(max_days)

    # 日付順にソートして返す
    selected.sort
  end

  # 選定された日付の EventDay レコードを作成する
  #
  # @param dates [Array<Date>] 活動日の日付配列
  # @return [Array<EventDay>] 作成された EventDay の配列
  def create_event_days(dates)
    dates.map do |date|
      @group.event_days.find_or_initialize_by(date: date).tap do |ed|
        ed.auto_generated = true
        ed.save!
      end
    end
  end

  # 対象日付範囲の参加可否データを取得する
  #
  # @param dates [Array<Date>] 対象日付の配列
  # @return [ActiveRecord::Relation<Availability>]
  def load_availabilities(dates)
    @group.availabilities.where(date: dates)
  end
end
