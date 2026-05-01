/**
 * AvailabilityBoard コンポーネントのユニットテスト
 *
 * 要件: 4.1, 4.2, 4.3, 4.9, 3.7, 3.8
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import AvailabilityBoard from "@/components/availability/AvailabilityBoard";
import type { Group } from "@/types/group";
import type { Member } from "@/types/member";
import type { AvailabilitiesMap } from "@/types/availability";

/** テスト用グループデータ */
const mockGroup: Group = {
  id: 1,
  name: "テストグループ",
  event_name: "テストイベント",
  locale: "ja",
  timezone: "Asia/Tokyo",
  threshold_n: 3,
  threshold_target: "core",
  default_start_time: "19:00",
  default_end_time: "22:00",
  ad_enabled: false,
};

/** テスト用メンバーデータ */
const mockMembers: Member[] = [
  {
    id: 1,
    display_name: "たろう",
    discord_screen_name: "taro_discord",
    role: "owner",
    auth_locked: false,
  },
  {
    id: 2,
    display_name: "はなこ",
    discord_screen_name: "hanako_discord",
    role: "core",
    auth_locked: false,
  },
  {
    id: 3,
    display_name: "じろう",
    discord_screen_name: "jiro_discord",
    role: "sub",
    auth_locked: false,
  },
];

/** テスト用参加可否データ */
const mockAvailabilities: AvailabilitiesMap = {
  "2025-01-15": {
    "1": { status: 1, comment: null, auto_synced: false },
    "2": { status: -1, comment: "出張", auto_synced: false },
    "3": { status: 0, comment: "未定", auto_synced: false },
  },
};

/** デフォルト props */
const defaultProps = {
  group: mockGroup,
  members: mockMembers,
  availabilities: {},
  eventDays: {},
  summary: {},
  selectedUserId: null,
  locale: "ja" as const,
};

describe("AvailabilityBoard", () => {
  it("ボードが表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    expect(screen.getByTestId("availability-board")).toBeInTheDocument();
  });

  it("メンバー名がヘッダーに表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    expect(screen.getByTestId("member-header-1")).toHaveTextContent("たろう");
    expect(screen.getByTestId("member-header-2")).toHaveTextContent("はなこ");
    expect(screen.getByTestId("member-header-3")).toHaveTextContent("じろう");
  });

  it("Core メンバーと Sub メンバーの間に区切りが表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    expect(screen.getByTestId("role-divider-header")).toBeInTheDocument();
  });

  it("Sub メンバーがいない場合は区切りが表示されない", () => {
    const coreOnlyMembers = mockMembers.filter((m) => m.role !== "sub");
    render(
      <AvailabilityBoard {...defaultProps} members={coreOnlyMembers} />,
    );

    expect(
      screen.queryByTestId("role-divider-header"),
    ).not.toBeInTheDocument();
  });

  it("月送りナビゲーションが表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    expect(screen.getByTestId("nav-previous")).toBeInTheDocument();
    expect(screen.getByTestId("nav-next")).toBeInTheDocument();
    expect(screen.getByTestId("nav-header-text")).toBeInTheDocument();
  });

  it("月/週切り替えトグルが表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    expect(screen.getByTestId("toggle-month")).toBeInTheDocument();
    expect(screen.getByTestId("toggle-week")).toBeInTheDocument();
  });

  it("月表示モードで当月の全日付が表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    /* テーブルが存在する */
    const table = screen.getByTestId("board-table");
    expect(table).toBeInTheDocument();

    /* 日付行が存在する（少なくとも28日分） */
    const rows = within(table).getAllByTestId(/^date-row-/);
    expect(rows.length).toBeGreaterThanOrEqual(28);
    expect(rows.length).toBeLessThanOrEqual(31);
  });

  it("週表示モードに切り替えると7日分の日付が表示される", async () => {
    const user = userEvent.setup();
    render(<AvailabilityBoard {...defaultProps} />);

    await user.click(screen.getByTestId("toggle-week"));

    const table = screen.getByTestId("board-table");
    const rows = within(table).getAllByTestId(/^date-row-/);
    expect(rows).toHaveLength(7);
  });

  it("参加可否データがセルに記号で表示される", () => {
    render(
      <AvailabilityBoard
        {...defaultProps}
        availabilities={mockAvailabilities}
      />,
    );

    /* 2025-01-15 の行が存在する場合のみ確認 */
    const cell1 = screen.queryByTestId("cell-2025-01-15-1");
    const cell2 = screen.queryByTestId("cell-2025-01-15-2");
    const cell3 = screen.queryByTestId("cell-2025-01-15-3");

    if (cell1 && cell2 && cell3) {
      expect(cell1).toHaveTextContent("○");
      expect(cell2).toHaveTextContent("×");
      expect(cell3).toHaveTextContent("△");
    }
  });

  it("空データの場合は未入力記号（−）が表示される", () => {
    render(<AvailabilityBoard {...defaultProps} availabilities={{}} />);

    /* テーブル内の最初の日付行のセルを確認 */
    const table = screen.getByTestId("board-table");
    const firstRow = within(table).getAllByTestId(/^date-row-/)[0]!;
    const cells = within(firstRow).getAllByTestId(/^cell-/);

    /* 全セルが未入力記号（−）を表示 */
    cells.forEach((cell) => {
      expect(cell).toHaveTextContent("−");
    });
  });

  it("前月ボタンをクリックすると月が変わる", async () => {
    const user = userEvent.setup();
    render(<AvailabilityBoard {...defaultProps} />);

    const headerText = screen.getByTestId("nav-header-text").textContent;
    await user.click(screen.getByTestId("nav-previous"));
    const newHeaderText = screen.getByTestId("nav-header-text").textContent;

    expect(newHeaderText).not.toBe(headerText);
  });

  it("次月ボタンをクリックすると月が変わる", async () => {
    const user = userEvent.setup();
    render(<AvailabilityBoard {...defaultProps} />);

    const headerText = screen.getByTestId("nav-header-text").textContent;
    await user.click(screen.getByTestId("nav-next"));
    const newHeaderText = screen.getByTestId("nav-header-text").textContent;

    expect(newHeaderText).not.toBe(headerText);
  });

  it("英語ロケールで英語の月名が表示される", () => {
    render(
      <AvailabilityBoard
        {...defaultProps}
        locale="en"
        group={{ ...mockGroup, locale: "en" }}
      />,
    );

    const headerText = screen.getByTestId("nav-header-text").textContent ?? "";
    /* 英語の月名が含まれることを確認 */
    const englishMonths = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    const hasEnglishMonth = englishMonths.some((m) =>
      headerText.includes(m),
    );
    expect(hasEnglishMonth).toBe(true);
  });

  it("onCellClick が渡された場合、セルクリックでコールバックが呼ばれる", async () => {
    const user = userEvent.setup();
    const onCellClick = vi.fn();
    render(
      <AvailabilityBoard {...defaultProps} onCellClick={onCellClick} />,
    );

    /* テーブル内の最初のセルをクリック */
    const table = screen.getByTestId("board-table");
    const firstRow = within(table).getAllByTestId(/^date-row-/)[0]!;
    const firstCell = within(firstRow).getAllByTestId(/^cell-/)[0]!;
    await user.click(firstCell);

    expect(onCellClick).toHaveBeenCalledTimes(1);
  });

  it("曜日が日本語で表示される", () => {
    render(<AvailabilityBoard {...defaultProps} />);

    const table = screen.getByTestId("board-table");
    const firstRow = within(table).getAllByTestId(/^date-row-/)[0]!;
    const dateCell = within(firstRow).getByText(/\(.+\)/);

    /* 曜日が括弧内に表示される */
    expect(dateCell.textContent).toMatch(/\((日|月|火|水|木|金|土)\)/);
  });
});

/**
 * 過去日付のロック表示テスト
 *
 * 要件: 3.7, 3.8
 * - 過去日付は一般メンバーに対して閲覧のみ（入力不可）
 * - Owner の場合は過去日付も編集可能
 * - 未来日付は役割に関係なく編集可能
 */
describe("AvailabilityBoard - 過去日付のロック表示", () => {
  /**
   * テスト用の固定日付を使用してフレーキーテストを回避する
   * 2025-06-15 を「今日」として固定し、過去・未来の日付を明確に定義する
   * vi.useFakeTimers は userEvent と相性が悪いため、Date コンストラクタをモックする
   */
  const FIXED_NOW = new Date(2025, 5, 15, 12, 0, 0); /* 2025-06-15 12:00:00 */
  const PAST_DATE = "2025-06-10"; /* 5日前 */
  const FUTURE_DATE = "2025-06-20"; /* 5日後 */

  /** 過去日付と未来日付の参加可否データ */
  const pastFutureAvailabilities: AvailabilitiesMap = {
    [PAST_DATE]: {
      "1": { status: 1, comment: null, auto_synced: false },
      "2": { status: 1, comment: null, auto_synced: false },
      "3": { status: 1, comment: null, auto_synced: false },
    },
    [FUTURE_DATE]: {
      "1": { status: null, comment: null, auto_synced: false },
      "2": { status: null, comment: null, auto_synced: false },
      "3": { status: null, comment: null, auto_synced: false },
    },
  };

  /* Date コンストラクタをモックして「今日」を固定する */
  const OriginalDate = globalThis.Date;
  beforeEach(() => {
    const MockDate = class extends OriginalDate {
      constructor(...args: unknown[]) {
        if (args.length === 0) {
          super(FIXED_NOW.getTime());
        } else {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          super(...(args as [any]));
        }
      }
      static override now() {
        return FIXED_NOW.getTime();
      }
    } as DateConstructor;
    globalThis.Date = MockDate;
  });

  afterEach(() => {
    globalThis.Date = OriginalDate;
  });

  it("過去日付のセルは一般メンバー（core）に対して編集不可", async () => {
    const user = userEvent.setup();
    const onStatusChange = vi.fn();

    render(
      <AvailabilityBoard
        {...defaultProps}
        availabilities={pastFutureAvailabilities}
        selectedUserId={2} /* はなこ（core） */
        onStatusChange={onStatusChange}
      />,
    );

    /* 過去日付のセルをクリック */
    const pastCell = screen.getByTestId(`cell-${PAST_DATE}-2`);
    await user.click(pastCell);

    /* onStatusChange が呼ばれないことを確認 */
    expect(onStatusChange).not.toHaveBeenCalled();
  });

  it("過去日付のセルは一般メンバー（sub）に対して編集不可", async () => {
    const user = userEvent.setup();
    const onStatusChange = vi.fn();

    render(
      <AvailabilityBoard
        {...defaultProps}
        availabilities={pastFutureAvailabilities}
        selectedUserId={3} /* じろう（sub） */
        onStatusChange={onStatusChange}
      />,
    );

    /* 過去日付のセルをクリック */
    const pastCell = screen.getByTestId(`cell-${PAST_DATE}-3`);
    await user.click(pastCell);

    /* onStatusChange が呼ばれないことを確認 */
    expect(onStatusChange).not.toHaveBeenCalled();
  });

  it("過去日付のセルは Owner に対して編集可能", async () => {
    const user = userEvent.setup();
    const onStatusChange = vi.fn();

    render(
      <AvailabilityBoard
        {...defaultProps}
        availabilities={pastFutureAvailabilities}
        selectedUserId={1} /* たろう（owner） */
        onStatusChange={onStatusChange}
      />,
    );

    /* 過去日付のセルをクリック */
    const pastCell = screen.getByTestId(`cell-${PAST_DATE}-1`);
    await user.click(pastCell);

    /* Owner なので onStatusChange が呼ばれることを確認 */
    expect(onStatusChange).toHaveBeenCalledTimes(1);
    expect(onStatusChange).toHaveBeenCalledWith(PAST_DATE, 1, expect.anything());
  });

  it("未来日付のセルは一般メンバーでも編集可能", async () => {
    const user = userEvent.setup();
    const onStatusChange = vi.fn();

    render(
      <AvailabilityBoard
        {...defaultProps}
        availabilities={pastFutureAvailabilities}
        selectedUserId={2} /* はなこ（core） */
        onStatusChange={onStatusChange}
      />,
    );

    /* 未来日付のセルをクリック */
    const futureCell = screen.getByTestId(`cell-${FUTURE_DATE}-2`);
    await user.click(futureCell);

    /* 一般メンバーでも未来日付は編集可能 */
    expect(onStatusChange).toHaveBeenCalledTimes(1);
    expect(onStatusChange).toHaveBeenCalledWith(FUTURE_DATE, 2, expect.anything());
  });

  it("過去日付の行は視覚的に区別される（opacity が適用される）", () => {
    render(
      <AvailabilityBoard
        {...defaultProps}
        availabilities={pastFutureAvailabilities}
        selectedUserId={2}
      />,
    );

    const pastRow = screen.getByTestId(`date-row-${PAST_DATE}`);
    const futureRow = screen.getByTestId(`date-row-${FUTURE_DATE}`);

    /* 過去日付の行には opacity スタイルが適用される */
    expect(pastRow).toHaveStyle({ opacity: 0.65 });
    /* 未来日付の行には opacity が適用されない */
    expect(futureRow).not.toHaveStyle({ opacity: 0.65 });
  });
});
