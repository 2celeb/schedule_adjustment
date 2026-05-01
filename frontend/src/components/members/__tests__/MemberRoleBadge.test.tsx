/**
 * MemberRoleBadge コンポーネントのユニットテスト
 *
 * 要件: 2.4, 2.5
 */
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import MemberRoleBadge from "@/components/members/MemberRoleBadge";

describe("MemberRoleBadge", () => {
  it("Owner 役割のバッジを表示する", () => {
    render(<MemberRoleBadge role="owner" />);
    expect(screen.getByText("オーナー")).toBeInTheDocument();
  });

  it("Core 役割のバッジを表示する", () => {
    render(<MemberRoleBadge role="core" />);
    expect(screen.getByText("コアメンバー")).toBeInTheDocument();
  });

  it("Sub 役割のバッジを表示する", () => {
    render(<MemberRoleBadge role="sub" />);
    expect(screen.getByText("サブメンバー")).toBeInTheDocument();
  });
});
