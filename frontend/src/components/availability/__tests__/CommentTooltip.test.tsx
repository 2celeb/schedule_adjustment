/**
 * CommentTooltip コンポーネントのユニットテスト
 *
 * 要件: 3.3, 3.4, 4.10
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  Table,
  TableBody,
  TableRow,
} from "@mui/material";
import CommentTooltip from "@/components/availability/CommentTooltip";

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

/** デフォルト props */
const defaultProps = {
  status: -1 as const,
  locale: "ja" as const,
  comment: null as string | null,
  autoSynced: false,
  showInput: false,
  onSaveComment: vi.fn(),
  onClose: vi.fn(),
};

describe("CommentTooltip", () => {
  it("子要素（セル）をレンダリングする", () => {
    renderInTable(
      <CommentTooltip {...defaultProps} data-testid="cell" />,
    );

    expect(screen.getByTestId("cell")).toBeInTheDocument();
    expect(screen.getByTestId("cell")).toHaveTextContent("×");
  });

  it("コメントがある場合にホバーでツールチップを表示する", async () => {
    const user = userEvent.setup();
    renderInTable(
      <CommentTooltip
        {...defaultProps}
        comment="出張のため"
        data-testid="cell"
      />,
    );

    await user.hover(screen.getByTestId("cell"));

    await waitFor(() => {
      expect(screen.getByRole("tooltip")).toBeInTheDocument();
      expect(screen.getByRole("tooltip")).toHaveTextContent("出張のため");
    });
  });

  it("コメントが null の場合はツールチップを表示しない", async () => {
    const user = userEvent.setup();
    renderInTable(
      <CommentTooltip {...defaultProps} comment={null} data-testid="cell" />,
    );

    await user.hover(screen.getByTestId("cell"));

    /* ツールチップが表示されないことを確認（少し待ってから） */
    await new Promise((r) => setTimeout(r, 300));
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("showInput=true の場合にポップオーバーを表示する", () => {
    renderInTable(
      <CommentTooltip {...defaultProps} showInput={true} data-testid="cell" />,
    );

    expect(screen.getByTestId("comment-input-form")).toBeInTheDocument();
  });

  it("ポップオーバーに TextField と保存/閉じるボタンがある", () => {
    renderInTable(
      <CommentTooltip {...defaultProps} showInput={true} data-testid="cell" />,
    );

    expect(screen.getByTestId("comment-input")).toBeInTheDocument();
    expect(screen.getByTestId("comment-save-button")).toBeInTheDocument();
    expect(screen.getByTestId("comment-close-button")).toBeInTheDocument();
  });

  it("保存ボタンをクリックすると onSaveComment が入力テキストで呼ばれる", async () => {
    const user = userEvent.setup();
    const onSaveComment = vi.fn();
    renderInTable(
      <CommentTooltip
        {...defaultProps}
        showInput={true}
        onSaveComment={onSaveComment}
        data-testid="cell"
      />,
    );

    const input = screen.getByTestId("comment-input-field");
    await user.type(input, "体調不良");
    await user.click(screen.getByTestId("comment-save-button"));

    expect(onSaveComment).toHaveBeenCalledWith("体調不良");
  });

  it("閉じるボタンをクリックすると onClose が呼ばれる", async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    renderInTable(
      <CommentTooltip
        {...defaultProps}
        showInput={true}
        onClose={onClose}
        data-testid="cell"
      />,
    );

    await user.click(screen.getByTestId("comment-close-button"));

    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("autoSynced=true の場合にポップオーバー内に自動設定テキストを表示する", () => {
    renderInTable(
      <CommentTooltip
        {...defaultProps}
        showInput={true}
        autoSynced={true}
        data-testid="cell"
      />,
    );

    expect(screen.getByTestId("auto-synced-indicator")).toBeInTheDocument();
    expect(screen.getByTestId("auto-synced-indicator")).toHaveTextContent(
      "Google カレンダーから自動設定",
    );
  });

  it("autoSynced=true でコメントなしの場合もツールチップを表示する", async () => {
    const user = userEvent.setup();
    renderInTable(
      <CommentTooltip
        {...defaultProps}
        comment={null}
        autoSynced={true}
        data-testid="cell"
      />,
    );

    await user.hover(screen.getByTestId("cell"));

    await waitFor(() => {
      expect(screen.getByRole("tooltip")).toBeInTheDocument();
      expect(screen.getByRole("tooltip")).toHaveTextContent(
        "Google カレンダーから自動設定",
      );
    });
  });

  it("既存コメントがある場合にポップオーバーの入力欄に初期値が設定される", () => {
    renderInTable(
      <CommentTooltip
        {...defaultProps}
        comment="既存コメント"
        showInput={true}
        data-testid="cell"
      />,
    );

    const input = screen.getByTestId("comment-input-field") as HTMLTextAreaElement;
    expect(input.value).toBe("既存コメント");
  });
});
