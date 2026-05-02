/**
 * GroupSettingsForm コンポーネントのユニットテスト
 *
 * 要件: 2.2, 4.12, 5.9
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import GroupSettingsForm from "@/components/settings/GroupSettingsForm";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string, fallback?: string) => {
      const translations: Record<string, string> = {
        "groupSettings.title": "グループ基本設定",
        "group.name": "グループ名",
        "group.eventName": "イベント名",
        "group.defaultStartTime": "デフォルト開始時間",
        "group.defaultEndTime": "デフォルト終了時間",
        "group.timezone": "タイムゾーン",
        "group.locale": "言語",
        "groupSettings.error.nameRequired": "グループ名を入力してください。",
        "groupSettings.error.eventNameRequired": "イベント名を入力してください。",
        "common.save": "保存",
      };
      return translations[key] ?? fallback ?? key;
    },
  }),
}));

const mockGroup = {
  id: 1,
  name: "テストグループ",
  event_name: "テスト活動",
  timezone: "Asia/Tokyo",
  default_start_time: "19:00",
  default_end_time: "22:00",
  locale: "ja",
};

describe("GroupSettingsForm", () => {
  let onUpdate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onUpdate = vi.fn();
  });

  it("タイトルが表示される", () => {
    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByText("グループ基本設定")).toBeInTheDocument();
  });

  it("グループ情報がフォームに反映される", () => {
    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByLabelText(/グループ名/)).toHaveValue("テストグループ");
    expect(screen.getByLabelText(/イベント名/)).toHaveValue("テスト活動");
  });

  it("保存ボタンをクリックすると onUpdate が呼ばれる", async () => {
    const user = userEvent.setup();

    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith({
      name: "テストグループ",
      event_name: "テスト活動",
      default_start_time: "19:00",
      default_end_time: "22:00",
      timezone: "Asia/Tokyo",
      locale: "ja",
    });
  });

  it("グループ名が空の場合はエラーが表示される", async () => {
    const user = userEvent.setup();

    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    const nameInput = screen.getByLabelText(/グループ名/);
    await user.clear(nameInput);
    await user.click(screen.getByText("保存"));

    expect(
      screen.getByText("グループ名を入力してください。"),
    ).toBeInTheDocument();
    expect(onUpdate).not.toHaveBeenCalled();
  });

  it("イベント名が空の場合はエラーが表示される", async () => {
    const user = userEvent.setup();

    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    const eventNameInput = screen.getByLabelText(/イベント名/);
    await user.clear(eventNameInput);
    await user.click(screen.getByText("保存"));

    expect(
      screen.getByText("イベント名を入力してください。"),
    ).toBeInTheDocument();
    expect(onUpdate).not.toHaveBeenCalled();
  });

  it("更新中は保存ボタンが無効になる", () => {
    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={true}
      />,
    );

    expect(screen.getByText("保存")).toBeDisabled();
  });

  it("グループ名を変更して保存できる", async () => {
    const user = userEvent.setup();

    render(
      <GroupSettingsForm
        group={mockGroup}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    const nameInput = screen.getByLabelText(/グループ名/);
    await user.clear(nameInput);
    await user.type(nameInput, "新しいグループ名");
    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "新しいグループ名",
      }),
    );
  });

  it("デフォルト時間が空の場合は null として送信される", async () => {
    const user = userEvent.setup();

    const groupWithoutTime = {
      ...mockGroup,
      default_start_time: null,
      default_end_time: null,
    };

    render(
      <GroupSettingsForm
        group={groupWithoutTime}
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        default_start_time: null,
        default_end_time: null,
      }),
    );
  });
});
