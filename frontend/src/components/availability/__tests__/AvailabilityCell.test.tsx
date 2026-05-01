/**
 * AvailabilityCell コンポーネントのユニットテスト
 *
 * 要件: 3.1, 3.2, 4.11, 4.12
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  Table,
  TableBody,
  TableRow,
} from "@mui/material";
import AvailabilityCell from "@/components/availability/AvailabilityCell";

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

describe("AvailabilityCell", () => {
  it("日本語ロケールで status=1 の場合に ○ を表示する", () => {
    renderInTable(
      <AvailabilityCell status={1} locale="ja" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).toHaveTextContent("○");
  });

  it("日本語ロケールで status=0 の場合に △ を表示する", () => {
    renderInTable(
      <AvailabilityCell status={0} locale="ja" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).toHaveTextContent("△");
  });

  it("日本語ロケールで status=-1 の場合に × を表示する", () => {
    renderInTable(
      <AvailabilityCell status={-1} locale="ja" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).toHaveTextContent("×");
  });

  it("日本語ロケールで status=null の場合に − を表示する", () => {
    renderInTable(
      <AvailabilityCell status={null} locale="ja" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).toHaveTextContent("−");
  });

  it("英語ロケールで status=1 の場合に ✓ を表示する", () => {
    renderInTable(
      <AvailabilityCell status={1} locale="en" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).toHaveTextContent("✓");
  });

  it("英語ロケールで status=-1 の場合に ✗ を表示する", () => {
    renderInTable(
      <AvailabilityCell status={-1} locale="en" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).toHaveTextContent("✗");
  });

  it("onClick が渡された場合にクリックでコールバックが呼ばれる", async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    renderInTable(
      <AvailabilityCell
        status={null}
        locale="ja"
        onClick={onClick}
        data-testid="cell"
      />,
    );

    await user.click(screen.getByTestId("cell"));
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it("disabled=true の場合はクリックしてもコールバックが呼ばれない", async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    renderInTable(
      <AvailabilityCell
        status={null}
        locale="ja"
        onClick={onClick}
        disabled
        data-testid="cell"
      />,
    );

    await user.click(screen.getByTestId("cell"));
    expect(onClick).not.toHaveBeenCalled();
  });

  it("onClick が渡された場合に role=button が設定される", () => {
    renderInTable(
      <AvailabilityCell
        status={null}
        locale="ja"
        onClick={() => {}}
        data-testid="cell"
      />,
    );
    expect(screen.getByTestId("cell")).toHaveAttribute("role", "button");
  });

  it("onClick が渡されていない場合は role=button が設定されない", () => {
    renderInTable(
      <AvailabilityCell status={null} locale="ja" data-testid="cell" />,
    );
    expect(screen.getByTestId("cell")).not.toHaveAttribute("role", "button");
  });

  it("キーボード操作（Enter）でコールバックが呼ばれる", async () => {
    const user = userEvent.setup();
    const onClick = vi.fn();
    renderInTable(
      <AvailabilityCell
        status={null}
        locale="ja"
        onClick={onClick}
        data-testid="cell"
      />,
    );

    const cell = screen.getByTestId("cell");
    cell.focus();
    await user.keyboard("{Enter}");
    expect(onClick).toHaveBeenCalledTimes(1);
  });
});
