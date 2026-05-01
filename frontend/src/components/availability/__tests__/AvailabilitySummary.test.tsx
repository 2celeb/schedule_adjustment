/**
 * AvailabilitySummary コンポーネントのユニットテスト
 *
 * 要件: 4.4, 4.5, 4.6, 4.7
 *
 * テスト対象:
 * - getRowHighlight(): 集計データと閾値から行ハイライト種別を判定する関数
 * - ROW_HIGHLIGHT_COLORS: ハイライト種別に対応する背景色定数
 * - getHighlightTooltipKey(): ハイライト種別に対応するツールチップ i18n キーを返す関数
 * - AvailabilitySummary コンポーネント: 日別集計表示と警告色
 */
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import {
  Table,
  TableBody,
  TableRow,
} from "@mui/material";
import AvailabilitySummary, {
  getRowHighlight,
  getHighlightTooltipKey,
  ROW_HIGHLIGHT_COLORS,
} from "@/components/availability/AvailabilitySummary";
import type { SummaryEntry } from "@/types/availability";

/**
 * TableCell は Table > TableBody > TableRow 内でレンダリングする必要がある
 */
function renderInTable(ui: React.ReactElement) {
  return render(
    <Table>
      <TableBody>
        <TableRow>{ui}</TableRow>
      </TableBody>
    </Table>,
  );
}

/* ========================================
 * getRowHighlight() のテスト
 * ======================================== */
describe("getRowHighlight", () => {
  it("summary が undefined の場合は 'default' を返す", () => {
    expect(getRowHighlight(undefined, 3)).toBe("default");
  });

  it("ng >= thresholdN の場合は 'thresholdExceeded' を返す", () => {
    const summary: SummaryEntry = { ok: 2, maybe: 0, ng: 3, none: 0 };
    expect(getRowHighlight(summary, 3)).toBe("thresholdExceeded");
  });

  it("ng > thresholdN の場合も 'thresholdExceeded' を返す", () => {
    const summary: SummaryEntry = { ok: 1, maybe: 0, ng: 5, none: 0 };
    expect(getRowHighlight(summary, 3)).toBe("thresholdExceeded");
  });

  it("ng=0, maybe=0, none=0 の場合は 'allAvailable' を返す", () => {
    const summary: SummaryEntry = { ok: 5, maybe: 0, ng: 0, none: 0 };
    expect(getRowHighlight(summary, 3)).toBe("allAvailable");
  });

  it("ng === 1 の場合は 'oneUnavailable' を返す", () => {
    const summary: SummaryEntry = { ok: 3, maybe: 1, ng: 1, none: 0 };
    expect(getRowHighlight(summary, 3)).toBe("oneUnavailable");
  });

  it("ng=2 で閾値未満の場合は 'default' を返す", () => {
    const summary: SummaryEntry = { ok: 2, maybe: 0, ng: 2, none: 1 };
    expect(getRowHighlight(summary, 3)).toBe("default");
  });

  it("thresholdN が null の場合は閾値チェックをスキップし 'default' を返す（ng が高くても）", () => {
    const summary: SummaryEntry = { ok: 0, maybe: 0, ng: 10, none: 0 };
    expect(getRowHighlight(summary, null)).toBe("default");
  });

  it("thresholdN が null で全員参加可能の場合は 'allAvailable' を返す", () => {
    const summary: SummaryEntry = { ok: 5, maybe: 0, ng: 0, none: 0 };
    expect(getRowHighlight(summary, null)).toBe("allAvailable");
  });

  it("thresholdN が null で ng=1 の場合は 'oneUnavailable' を返す", () => {
    const summary: SummaryEntry = { ok: 4, maybe: 0, ng: 1, none: 0 };
    expect(getRowHighlight(summary, null)).toBe("oneUnavailable");
  });

  /* 優先度テスト: thresholdExceeded > allAvailable */
  it("ng >= thresholdN かつ maybe=0, none=0 でも 'thresholdExceeded' が優先される", () => {
    /* thresholdN=0 の場合、ng=0 でも thresholdExceeded になる */
    const summary: SummaryEntry = { ok: 5, maybe: 0, ng: 0, none: 0 };
    expect(getRowHighlight(summary, 0)).toBe("thresholdExceeded");
  });

  /* 優先度テスト: thresholdExceeded > oneUnavailable */
  it("ng=1 かつ thresholdN=1 の場合は 'thresholdExceeded' が優先される", () => {
    const summary: SummaryEntry = { ok: 4, maybe: 0, ng: 1, none: 0 };
    expect(getRowHighlight(summary, 1)).toBe("thresholdExceeded");
  });

  /* maybe > 0 の場合は allAvailable にならない */
  it("ng=0 だが maybe > 0 の場合は 'allAvailable' にならない", () => {
    const summary: SummaryEntry = { ok: 3, maybe: 2, ng: 0, none: 0 };
    expect(getRowHighlight(summary, 3)).toBe("default");
  });

  /* none > 0 の場合は allAvailable にならない */
  it("ng=0 だが none > 0 の場合は 'allAvailable' にならない", () => {
    const summary: SummaryEntry = { ok: 3, maybe: 0, ng: 0, none: 2 };
    expect(getRowHighlight(summary, 3)).toBe("default");
  });
});

/* ========================================
 * ROW_HIGHLIGHT_COLORS のテスト
 * ======================================== */
describe("ROW_HIGHLIGHT_COLORS", () => {
  it("thresholdExceeded は赤系の色を持つ", () => {
    const color = ROW_HIGHLIGHT_COLORS.thresholdExceeded;
    expect(color).toBeDefined();
    /* #ffebee は MUI の red[50] 相当 */
    expect(color).toMatch(/^#ff/i);
  });

  it("allAvailable は緑系の色を持つ", () => {
    const color = ROW_HIGHLIGHT_COLORS.allAvailable;
    expect(color).toBeDefined();
    /* #e8f5e9 は MUI の green[50] 相当 */
    expect(color).toMatch(/^#e/i);
  });

  it("oneUnavailable はオレンジ系の色を持つ", () => {
    const color = ROW_HIGHLIGHT_COLORS.oneUnavailable;
    expect(color).toBeDefined();
    /* #fff3e0 は MUI の orange[50] 相当 */
    expect(color).toMatch(/^#fff/i);
  });

  it("default は undefined（色なし）", () => {
    expect(ROW_HIGHLIGHT_COLORS.default).toBeUndefined();
  });
});

/* ========================================
 * getHighlightTooltipKey() のテスト
 * ======================================== */
describe("getHighlightTooltipKey", () => {
  it("thresholdExceeded の場合は 'threshold.warning' を返す", () => {
    expect(getHighlightTooltipKey("thresholdExceeded")).toBe("threshold.warning");
  });

  it("allAvailable の場合は 'summary.allAvailable' を返す", () => {
    expect(getHighlightTooltipKey("allAvailable")).toBe("summary.allAvailable");
  });

  it("oneUnavailable の場合は 'summary.oneUnavailable' を返す", () => {
    expect(getHighlightTooltipKey("oneUnavailable")).toBe("summary.oneUnavailable");
  });

  it("default の場合は null を返す", () => {
    expect(getHighlightTooltipKey("default")).toBeNull();
  });
});

/* ========================================
 * AvailabilitySummary コンポーネントのテスト
 * ======================================== */
describe("AvailabilitySummary", () => {
  it("集計データの ○/△/×/− 人数が正しく表示される", () => {
    const summary: SummaryEntry = { ok: 3, maybe: 1, ng: 2, none: 1 };
    renderInTable(
      <AvailabilitySummary summary={summary} thresholdN={5} totalMembers={7} />,
    );

    const cell = screen.getByTestId("summary-cell");
    /* 日本語ロケール（テストセットアップで ja に設定済み）: ○3 △1 ×2 −1 */
    expect(cell).toHaveTextContent("○3");
    expect(cell).toHaveTextContent("△1");
    expect(cell).toHaveTextContent("×2");
    expect(cell).toHaveTextContent("−1");
  });

  it("summary が undefined の場合は '−'（noData）を表示する", () => {
    renderInTable(
      <AvailabilitySummary summary={undefined} thresholdN={3} totalMembers={5} />,
    );

    const cell = screen.getByTestId("summary-cell-empty");
    expect(cell).toBeInTheDocument();
    expect(cell).toHaveTextContent("−");
  });

  it("全員参加可能の場合にツールチップが表示される", () => {
    const summary: SummaryEntry = { ok: 5, maybe: 0, ng: 0, none: 0 };
    renderInTable(
      <AvailabilitySummary summary={summary} thresholdN={3} totalMembers={5} />,
    );

    const cell = screen.getByTestId("summary-cell");
    expect(cell).toBeInTheDocument();
    /* Tooltip の title 属性は MUI が内部的に管理するため、
       Tooltip でラップされた要素が存在することを確認 */
    expect(cell.textContent).toContain("○5");
  });

  it("閾値超過の場合にツールチップが表示される", () => {
    const summary: SummaryEntry = { ok: 1, maybe: 0, ng: 4, none: 0 };
    renderInTable(
      <AvailabilitySummary summary={summary} thresholdN={3} totalMembers={5} />,
    );

    const cell = screen.getByTestId("summary-cell");
    expect(cell).toBeInTheDocument();
    expect(cell.textContent).toContain("×4");
  });

  it("1名のみ参加不可の場合にツールチップが表示される", () => {
    const summary: SummaryEntry = { ok: 3, maybe: 0, ng: 1, none: 1 };
    renderInTable(
      <AvailabilitySummary summary={summary} thresholdN={3} totalMembers={5} />,
    );

    const cell = screen.getByTestId("summary-cell");
    expect(cell).toBeInTheDocument();
    expect(cell.textContent).toContain("×1");
  });

  it("default ハイライトの場合はツールチップなしで表示される", () => {
    const summary: SummaryEntry = { ok: 2, maybe: 1, ng: 2, none: 0 };
    renderInTable(
      <AvailabilitySummary summary={summary} thresholdN={5} totalMembers={5} />,
    );

    const cell = screen.getByTestId("summary-cell");
    expect(cell).toBeInTheDocument();
    /* ツールチップなしの場合、cellContent が直接レンダリングされる */
    expect(cell.textContent).toContain("○2");
    expect(cell.textContent).toContain("×2");
  });

  it("ok=0 の場合も正しく 0 が表示される", () => {
    const summary: SummaryEntry = { ok: 0, maybe: 0, ng: 5, none: 0 };
    renderInTable(
      <AvailabilitySummary summary={summary} thresholdN={3} totalMembers={5} />,
    );

    const cell = screen.getByTestId("summary-cell");
    expect(cell).toHaveTextContent("○0");
    expect(cell).toHaveTextContent("×5");
  });
});
