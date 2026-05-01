/**
 * EventDayMarker コンポーネントのユニットテスト
 *
 * 要件: 5.10, 5.11
 */
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import EventDayMarker from "@/components/availability/EventDayMarker";
import type { EventDayEntry } from "@/types/availability";

/** 確定済み活動日（デフォルト時間） */
const confirmedEntry: EventDayEntry = {
  start_time: "19:00",
  end_time: "22:00",
  confirmed: true,
  custom_time: false,
};

/** 未確定活動日 */
const unconfirmedEntry: EventDayEntry = {
  start_time: "19:00",
  end_time: "22:00",
  confirmed: false,
  custom_time: false,
};

/** 確定済み + カスタム時間 */
const confirmedCustomEntry: EventDayEntry = {
  start_time: "18:00",
  end_time: "21:00",
  confirmed: true,
  custom_time: true,
};

/** 未確定 + カスタム時間 */
const unconfirmedCustomEntry: EventDayEntry = {
  start_time: "20:00",
  end_time: "23:00",
  confirmed: false,
  custom_time: true,
};

describe("EventDayMarker", () => {
  it("eventDay が undefined の場合は何も表示しない", () => {
    const { container } = render(<EventDayMarker eventDay={undefined} />);
    expect(container.innerHTML).toBe("");
  });

  it("確定済み活動日のマーカーが表示される", () => {
    render(<EventDayMarker eventDay={confirmedEntry} />);

    expect(screen.getByTestId("event-day-marker")).toBeInTheDocument();
    expect(
      screen.getByTestId("event-day-marker-confirmed"),
    ).toBeInTheDocument();
  });

  it("未確定活動日のマーカーが表示される", () => {
    render(<EventDayMarker eventDay={unconfirmedEntry} />);

    expect(screen.getByTestId("event-day-marker")).toBeInTheDocument();
    expect(
      screen.getByTestId("event-day-marker-unconfirmed"),
    ).toBeInTheDocument();
  });

  it("custom_time が true の場合に赤の「!」マークが表示される", () => {
    render(<EventDayMarker eventDay={confirmedCustomEntry} />);

    const customMarker = screen.getByTestId("event-day-custom-time-marker");
    expect(customMarker).toBeInTheDocument();
    expect(customMarker).toHaveTextContent("!");
  });

  it("custom_time が false の場合は「!」マークが表示されない", () => {
    render(<EventDayMarker eventDay={confirmedEntry} />);

    expect(
      screen.queryByTestId("event-day-custom-time-marker"),
    ).not.toBeInTheDocument();
  });

  it("custom_time が true の場合にホバーで時間がツールチップに表示される", async () => {
    const user = userEvent.setup();
    render(<EventDayMarker eventDay={confirmedCustomEntry} />);

    const customMarker = screen.getByTestId("event-day-custom-time-marker");
    await user.hover(customMarker);

    /* ツールチップに開始・終了時間が含まれる */
    const tooltip = await screen.findByRole("tooltip");
    expect(tooltip).toHaveTextContent("18:00");
    expect(tooltip).toHaveTextContent("21:00");
  });

  it("未確定 + カスタム時間でも「!」マークが表示される", () => {
    render(<EventDayMarker eventDay={unconfirmedCustomEntry} />);

    expect(
      screen.getByTestId("event-day-marker-unconfirmed"),
    ).toBeInTheDocument();
    expect(
      screen.getByTestId("event-day-custom-time-marker"),
    ).toBeInTheDocument();
  });
});
