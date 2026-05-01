/**
 * NotificationSettings コンポーネントのユニットテスト
 *
 * 要件: 6.8
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import NotificationSettings from "@/components/settings/NotificationSettings";
import type { AutoScheduleRule } from "@/hooks/useGroupSettings";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string, fallback?: string) => {
      const translations: Record<string, string> = {
        "notification.title": "通知設定",
        "notification.remindDaysBefore": "リマインド開始日",
        "notification.activityNotifyHoursBefore": "当日通知時間",
        "notification.channel": "通知チャンネル",
        "notification.activityNotifyMessage": "当日通知メッセージ",
        "notification.remindDaysHelp": "確定日の何日前からリマインドを開始するか",
        "notification.notifyHoursHelp": "活動開始の何時間前に通知するか",
        "notification.channelHelp": "空欄の場合はデフォルトチャンネルに投稿されます",
        "notification.messagePlaceholder": "空欄の場合はデフォルトメッセージが使用されます",
        "notification.messageHelp": "活動日当日に投稿されるメッセージ",
        "notification.error.remindDaysNegative": "リマインド開始日は0以上で指定してください。",
        "notification.error.notifyHoursNegative": "当日通知時間は0以上で指定してください。",
        "common.save": "保存",
      };
      return translations[key] ?? fallback ?? key;
    },
  }),
}));

const mockRule: AutoScheduleRule = {
  id: 1,
  group_id: 1,
  max_days_per_week: 3,
  min_days_per_week: 1,
  deprioritized_days: [],
  excluded_days: [],
  week_start_day: 1,
  confirm_days_before: 3,
  remind_days_before_confirm: 2,
  confirm_time: "21:00",
  activity_notify_hours_before: 8,
  activity_notify_channel_id: "channel-123",
  activity_notify_message: "今日は活動日です！",
};

describe("NotificationSettings", () => {
  let onUpdate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onUpdate = vi.fn();
  });

  it("タイトルが表示される", () => {
    render(
      <NotificationSettings
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByText("通知設定")).toBeInTheDocument();
  });

  it("ルールの値がフォームに反映される", () => {
    render(
      <NotificationSettings
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    const remindInput = screen.getByLabelText("リマインド開始日");
    expect(remindInput).toHaveValue(2);

    const notifyInput = screen.getByLabelText("当日通知時間");
    expect(notifyInput).toHaveValue(8);
  });

  it("保存ボタンをクリックすると onUpdate が呼ばれる", async () => {
    const user = userEvent.setup();

    render(
      <NotificationSettings
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith({
      remind_days_before_confirm: 2,
      activity_notify_hours_before: 8,
      activity_notify_channel_id: "channel-123",
      activity_notify_message: "今日は活動日です！",
    });
  });

  it("更新中は保存ボタンが無効になる", () => {
    render(
      <NotificationSettings
        rule={mockRule}
        onUpdate={onUpdate}
        isUpdating={true}
      />,
    );

    expect(screen.getByText("保存")).toBeDisabled();
  });

  it("ルールが undefined の場合はデフォルト値が表示される", () => {
    render(
      <NotificationSettings
        rule={undefined}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByText("通知設定")).toBeInTheDocument();

    const remindInput = screen.getByLabelText("リマインド開始日");
    expect(remindInput).toHaveValue(2);

    const notifyInput = screen.getByLabelText("当日通知時間");
    expect(notifyInput).toHaveValue(8);
  });

  it("空のチャンネル ID は null として送信される", async () => {
    const ruleWithoutChannel = {
      ...mockRule,
      activity_notify_channel_id: null,
      activity_notify_message: null,
    };

    const user = userEvent.setup();

    render(
      <NotificationSettings
        rule={ruleWithoutChannel}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        activity_notify_channel_id: null,
        activity_notify_message: null,
      }),
    );
  });
});
