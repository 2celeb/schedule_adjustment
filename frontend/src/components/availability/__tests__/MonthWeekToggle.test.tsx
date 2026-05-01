/**
 * MonthWeekToggle コンポーネントのユニットテスト
 *
 * 要件: 4.2
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import MonthWeekToggle, {
  type ViewMode,
} from "@/components/availability/MonthWeekToggle";

describe("MonthWeekToggle", () => {
  it("月と週のトグルボタンを表示する", () => {
    const onChange = vi.fn();
    render(<MonthWeekToggle viewMode="month" onViewModeChange={onChange} />);

    expect(screen.getByTestId("toggle-month")).toBeInTheDocument();
    expect(screen.getByTestId("toggle-week")).toBeInTheDocument();
    expect(screen.getByText("月")).toBeInTheDocument();
    expect(screen.getByText("週")).toBeInTheDocument();
  });

  it("月モードが選択状態のとき月ボタンが pressed になる", () => {
    const onChange = vi.fn();
    render(<MonthWeekToggle viewMode="month" onViewModeChange={onChange} />);

    expect(screen.getByTestId("toggle-month")).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(screen.getByTestId("toggle-week")).toHaveAttribute(
      "aria-pressed",
      "false",
    );
  });

  it("週モードが選択状態のとき週ボタンが pressed になる", () => {
    const onChange = vi.fn();
    render(<MonthWeekToggle viewMode="week" onViewModeChange={onChange} />);

    expect(screen.getByTestId("toggle-week")).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(screen.getByTestId("toggle-month")).toHaveAttribute(
      "aria-pressed",
      "false",
    );
  });

  it("週ボタンをクリックすると onViewModeChange が week で呼ばれる", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn<(mode: ViewMode) => void>();
    render(<MonthWeekToggle viewMode="month" onViewModeChange={onChange} />);

    await user.click(screen.getByTestId("toggle-week"));

    expect(onChange).toHaveBeenCalledWith("week");
  });

  it("月ボタンをクリックすると onViewModeChange が month で呼ばれる", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn<(mode: ViewMode) => void>();
    render(<MonthWeekToggle viewMode="week" onViewModeChange={onChange} />);

    await user.click(screen.getByTestId("toggle-month"));

    expect(onChange).toHaveBeenCalledWith("month");
  });
});
