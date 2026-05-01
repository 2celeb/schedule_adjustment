/**
 * LockIcon コンポーネントのユニットテスト
 *
 * 要件: 1.4, 1.5
 */
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import LockIcon from "@/components/auth/LockIcon";

describe("LockIcon", () => {
  it("🔒 アイコンを表示する", () => {
    render(<LockIcon />);
    expect(screen.getByTestId("LockIcon")).toBeInTheDocument();
  });

  it("aria-label に「Google 認証が必要です」が設定される", () => {
    render(<LockIcon />);
    const icon = screen.getByLabelText("Google 認証が必要です");
    expect(icon).toBeInTheDocument();
  });

  it("デフォルトサイズが 14px である", () => {
    render(<LockIcon />);
    const icon = screen.getByTestId("LockIcon");
    expect(icon).toHaveStyle({ fontSize: "14px" });
  });

  it("カスタムサイズを指定できる", () => {
    render(<LockIcon size={24} />);
    const icon = screen.getByTestId("LockIcon");
    expect(icon).toHaveStyle({ fontSize: "24px" });
  });
});
