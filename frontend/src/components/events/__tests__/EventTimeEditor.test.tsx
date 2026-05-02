/**
 * EventTimeEditor コンポーネントのユニットテスト
 *
 * 要件: 5.9
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import EventTimeEditor from "@/components/events/EventTimeEditor";
import type { EventDay } from "@/hooks/useGroupSettings";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const translations: Record<string, string> = {
        "common.edit": "編集",
      };
      return translations[key] ?? key;
    },
  }),
}));

const mockEventDay: EventDay = {
  id: 1,
  group_id: 1,
  date: "2026-05-05",
  start_time: "19:00",
  end_time: "22:00",
  auto_generated: false,
  confirmed: true,
  confirmed_at: "2026-05-01T12:00:00Z",
  custom_time: false,
};

describe("EventTimeEditor", () => {
  let onUpdate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onUpdate = vi.fn();
  });

  it("Owner でない場合は時間のみ表示される", () => {
    render(
      <EventTimeEditor
        eventDay={mockEventDay}
        onUpdate={onUpdate}
        isOwner={false}
      />,
    );

    expect(screen.getByText("19:00 - 22:00")).toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });

  it("Owner の場合は編集ボタンが表示される", () => {
    render(
      <EventTimeEditor
        eventDay={mockEventDay}
        onUpdate={onUpdate}
        isOwner={true}
      />,
    );

    expect(screen.getByText("19:00 - 22:00")).toBeInTheDocument();
    /* 編集アイコンボタンが存在する */
    const buttons = screen.getAllByRole("button");
    expect(buttons.length).toBeGreaterThanOrEqual(1);
  });

  it("編集ボタンをクリックすると入力フィールドが表示される", async () => {
    const user = userEvent.setup();

    render(
      <EventTimeEditor
        eventDay={mockEventDay}
        onUpdate={onUpdate}
        isOwner={true}
      />,
    );

    /* 編集ボタンをクリック */
    const editButton = screen.getAllByRole("button")[0]!;
    await user.click(editButton);

    /* 時間入力フィールドが表示される */
    const timeInputs = screen.getAllByDisplayValue("19:00");
    expect(timeInputs.length).toBeGreaterThanOrEqual(1);
  });

  it("キャンセルボタンで編集モードを終了する", async () => {
    const user = userEvent.setup();

    render(
      <EventTimeEditor
        eventDay={mockEventDay}
        onUpdate={onUpdate}
        isOwner={true}
      />,
    );

    /* 編集モードに入る */
    const editButton = screen.getAllByRole("button")[0]!;
    await user.click(editButton);

    /* キャンセルボタンをクリック（CloseIcon のボタン） */
    const buttons = screen.getAllByRole("button");
    const cancelButton = buttons[buttons.length - 1]!; // 最後のボタンがキャンセル
    await user.click(cancelButton);

    /* 表示モードに戻る */
    expect(screen.getByText("19:00 - 22:00")).toBeInTheDocument();
    expect(onUpdate).not.toHaveBeenCalled();
  });
});
