/**
 * MemberAvatar コンポーネントのユニットテスト
 *
 * 要件: 1.2, 1.4, 2.3, 2.4
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import MemberAvatar from "@/components/members/MemberAvatar";
import type { Member } from "@/types/member";

/** テスト用メンバーデータ */
const baseMember: Member = {
  id: 1,
  display_name: "テストユーザー",
  discord_screen_name: "テストユーザー",
  role: "core",
  auth_locked: false,
};

describe("MemberAvatar", () => {
  it("メンバー名を表示する", () => {
    render(
      <MemberAvatar member={baseMember} selected={false} onClick={() => {}} />,
    );
    expect(screen.getByText("テストユーザー")).toBeInTheDocument();
  });

  it("auth_locked=true の場合は 🔒 アイコンを表示する", () => {
    const lockedMember: Member = { ...baseMember, auth_locked: true };
    render(
      <MemberAvatar member={lockedMember} selected={false} onClick={() => {}} />,
    );
    expect(screen.getByTestId("LockIcon")).toBeInTheDocument();
  });

  it("auth_locked=false の場合は 🔒 アイコンを表示しない", () => {
    render(
      <MemberAvatar member={baseMember} selected={false} onClick={() => {}} />,
    );
    expect(screen.queryByTestId("LockIcon")).not.toBeInTheDocument();
  });

  it("クリック時に onClick コールバックが呼ばれる", async () => {
    const handleClick = vi.fn();
    const user = userEvent.setup();
    render(
      <MemberAvatar member={baseMember} selected={false} onClick={handleClick} />,
    );
    await user.click(screen.getByText("テストユーザー"));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it("役割バッジを表示する", () => {
    render(
      <MemberAvatar member={baseMember} selected={false} onClick={() => {}} />,
    );
    expect(screen.getByText("コアメンバー")).toBeInTheDocument();
  });

  it("Discord スクリーン名が異なる場合に Tooltip が存在する", () => {
    const customNameMember: Member = {
      ...baseMember,
      display_name: "カスタム名",
      discord_screen_name: "discord_user",
    };
    render(
      <MemberAvatar
        member={customNameMember}
        selected={false}
        onClick={() => {}}
      />,
    );
    expect(screen.getByText("カスタム名")).toBeInTheDocument();
  });

  it("選択状態で aria-pressed=true が設定される", () => {
    render(
      <MemberAvatar member={baseMember} selected={true} onClick={() => {}} />,
    );
    const chip = screen.getByRole("button", { pressed: true });
    expect(chip).toBeInTheDocument();
  });
});
