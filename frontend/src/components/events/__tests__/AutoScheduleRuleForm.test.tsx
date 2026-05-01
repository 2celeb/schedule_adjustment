/**
 * AutoScheduleRuleForm コンポーネントのユニットテスト
 *
 * 要件: 5.2, 5.3
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import AutoScheduleRuleForm from "@/components/events/AutoScheduleRuleForm";
import type { AutoScheduleRule } from "@/hooks/useGroupSettings";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const translations: Record<string, string> = {
        "autoSchedule.title": "自動確定ルール",
        "autoSchedule.maxDaysPerWeek": "最大活動日数/週",
        "autoSchedule.minDaysPerWeek": "最低活動日数/週",
        "autoSchedule.deprioritizedDays": "優先度を下げる曜日",
        "autoSchedule.excludedDays": "除外曜日",
        "autoSchedule.weekStartDay": "週の始まり",
        "autoSchedule.confirmDaysBefore": "確定日",
        "autoSchedule.confirmTime": "確定時刻",
        "common.save": "保存",
        "weekday.0": "日",
        "weekday.1": "月",
        "weekday.2": "火",
        "weekday.3": "水",
        "weekday.4": "木",
        "weekday.5": "金",
        "weekday.6": "土",
      };
      return translations[key] ?? key;
    },
  }),
}));

const mockRule: AutoScheduleRule = {
  id: 1,
  group_id: 1,
  max_days_per_week: 3,
  min_days_per_week: 1,
  deprioritized_days: [0, 6],
  excluded_days: [0],
  week_start_day: 1,
  confirm_days_before: 3,
  remind_days_before_confirm: 2,
  confirm_time: "21:00",
  activity_notify_hours_before: 8,
  activity_notify_channel_id: null,
  activity_notify_message: null,
};

describe("AutoScheduleRuleForm", () => {
  let onUpdate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onUpdate = vi.fn();
  });

  it("タイトルが表示される", () => {
    render(
      <AutoScheduleRuleForm
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByText("自動確定ルール")).toBeInTheDocument();
  });

  it("ルールの値がフォームに反映される", () => {
    render(
      <AutoScheduleRuleForm
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    const maxInput = screen.getByLabelText("最大活動日数/週");
    expect(maxInput).toHaveValue(3);

    const minInput = screen.getByLabelText("最低活動日数/週");
    expect(minInput).toHaveValue(1);
  });

  it("保存ボタンをクリックすると onUpdate が呼ばれる", async () => {
    const user = userEvent.setup();

    render(
      <AutoScheduleRuleForm
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith({
      max_days_per_week: 3,
      min_days_per_week: 1,
      deprioritized_days: [0, 6],
      excluded_days: [0],
      week_start_day: 1,
      confirm_days_before: 3,
      confirm_time: "21:00",
    });
  });

  it("更新中は保存ボタンが無効になる", () => {
    render(
      <AutoScheduleRuleForm
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={true}
      />,
    );

    expect(screen.getByText("保存")).toBeDisabled();
  });

  it("ルールが undefined の場合はデフォルト値が表示される", () => {
    render(
      <AutoScheduleRuleForm
        rule={undefined}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByText("自動確定ルール")).toBeInTheDocument();
  });

  it("曜日チップが表示される", () => {
    render(
      <AutoScheduleRuleForm
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    /* 優先度を下げる曜日と除外曜日の両方に曜日チップが表示される */
    const dayChips = screen.getAllByText("日");
    expect(dayChips.length).toBeGreaterThanOrEqual(2);
  });
});
