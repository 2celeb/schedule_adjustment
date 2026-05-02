/**
 * ThresholdSettings コンポーネントのユニットテスト
 *
 * 要件: 4.8
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import ThresholdSettings from "@/components/settings/ThresholdSettings";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string, fallback?: string) => {
      const translations: Record<string, string> = {
        "threshold.title": "閾値設定",
        "threshold.count": "閾値人数",
        "threshold.countHelp":
          "この人数以上が参加不可の場合に警告表示されます。空欄で無効。",
        "threshold.target.label": "対象",
        "threshold.target.core": "コアメンバーのみ",
        "threshold.target.all": "全メンバー",
        "threshold.error.countMin": "閾値人数は1以上で指定してください。",
        "common.save": "保存",
      };
      return translations[key] ?? fallback ?? key;
    },
  }),
}));

describe("ThresholdSettings", () => {
  let onUpdate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onUpdate = vi.fn();
  });

  it("タイトルが表示される", () => {
    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByText("閾値設定")).toBeInTheDocument();
  });

  it("閾値人数がフォームに反映される", () => {
    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByLabelText("閾値人数")).toHaveValue(3);
  });

  it("閾値対象のラジオボタンが表示される", () => {
    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByLabelText("コアメンバーのみ")).toBeChecked();
    expect(screen.getByLabelText("全メンバー")).not.toBeChecked();
  });

  it("閾値対象を「全メンバー」に変更できる", async () => {
    const user = userEvent.setup();

    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByLabelText("全メンバー"));
    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith({
      threshold_n: 3,
      threshold_target: "all",
    });
  });

  it("保存ボタンをクリックすると onUpdate が呼ばれる", async () => {
    const user = userEvent.setup();

    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith({
      threshold_n: 3,
      threshold_target: "core",
    });
  });

  it("閾値人数が null の場合は空欄で表示される", () => {
    render(
      <ThresholdSettings
        thresholdN={null}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(screen.getByLabelText("閾値人数")).toHaveValue(null);
  });

  it("閾値人数が空の場合は null として送信される", async () => {
    const user = userEvent.setup();

    render(
      <ThresholdSettings
        thresholdN={null}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    await user.click(screen.getByText("保存"));

    expect(onUpdate).toHaveBeenCalledWith({
      threshold_n: null,
      threshold_target: "core",
    });
  });

  it("更新中は保存ボタンが無効になる", () => {
    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={true}
      />,
    );

    expect(screen.getByText("保存")).toBeDisabled();
  });

  it("ヘルプテキストが表示される", () => {
    render(
      <ThresholdSettings
        thresholdN={3}
        thresholdTarget="core"
        onUpdate={onUpdate}
        isUpdating={false}
      />,
    );

    expect(
      screen.getByText(
        "この人数以上が参加不可の場合に警告表示されます。空欄で無効。",
      ),
    ).toBeInTheDocument();
  });
});
