/**
 * MemberSelector コンポーネントのユニットテスト
 *
 * 要件: 1.2, 1.3, 1.5, 2.3, 2.4
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import MemberSelector, {
  loadSelectedUserId,
} from "@/components/members/MemberSelector";
import type { Member } from "@/types/member";

/** テスト用メンバーデータ */
const members: Member[] = [
  {
    id: 1,
    display_name: "えれん",
    discord_screen_name: "eren_discord",
    role: "core",
    auth_locked: false,
  },
  {
    id: 2,
    display_name: "みかさ",
    discord_screen_name: "mikasa_discord",
    role: "core",
    auth_locked: true,
  },
  {
    id: 3,
    display_name: "あるみん",
    discord_screen_name: "あるみん",
    role: "sub",
    auth_locked: false,
  },
];

describe("MemberSelector", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("全メンバーの名前を表示する", () => {
    render(
      <MemberSelector
        members={members}
        selectedUserId={null}
        onSelectUser={() => {}}
      />,
    );
    expect(screen.getByText("えれん")).toBeInTheDocument();
    expect(screen.getByText("みかさ")).toBeInTheDocument();
    expect(screen.getByText("あるみん")).toBeInTheDocument();
  });

  it("メンバー選択タイトルを表示する", () => {
    render(
      <MemberSelector
        members={members}
        selectedUserId={null}
        onSelectUser={() => {}}
      />,
    );
    expect(screen.getByText("メンバー選択")).toBeInTheDocument();
  });

  it("メンバーをクリックすると onSelectUser が呼ばれる", async () => {
    const handleSelect = vi.fn();
    const user = userEvent.setup();
    render(
      <MemberSelector
        members={members}
        selectedUserId={null}
        onSelectUser={handleSelect}
      />,
    );
    await user.click(screen.getByText("えれん"));
    expect(handleSelect).toHaveBeenCalledWith(1);
  });

  it("メンバー選択時に localStorage に selectedUserId を保存する", async () => {
    const handleSelect = vi.fn();
    const user = userEvent.setup();
    render(
      <MemberSelector
        members={members}
        selectedUserId={null}
        onSelectUser={handleSelect}
      />,
    );
    await user.click(screen.getByText("えれん"));
    expect(localStorage.getItem("selectedUserId")).toBe("1");
  });

  it("🔒 付きユーザー選択時に Google ログインボタンを表示する", () => {
    render(
      <MemberSelector
        members={members}
        selectedUserId={2}
        onSelectUser={() => {}}
      />,
    );
    expect(screen.getByText("Google でログイン")).toBeInTheDocument();
  });

  it("🔒 なしユーザー選択時は Google ログインボタンを表示しない", () => {
    render(
      <MemberSelector
        members={members}
        selectedUserId={1}
        onSelectUser={() => {}}
      />,
    );
    expect(screen.queryByText("Google でログイン")).not.toBeInTheDocument();
  });

  it("未選択時は Google ログインボタンを表示しない", () => {
    render(
      <MemberSelector
        members={members}
        selectedUserId={null}
        onSelectUser={() => {}}
      />,
    );
    expect(screen.queryByText("Google でログイン")).not.toBeInTheDocument();
  });
});

describe("loadSelectedUserId", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it("localStorage に値がない場合は null を返す", () => {
    expect(loadSelectedUserId()).toBeNull();
  });

  it("localStorage に有効な数値がある場合はその値を返す", () => {
    localStorage.setItem("selectedUserId", "42");
    expect(loadSelectedUserId()).toBe(42);
  });

  it("localStorage に無効な値がある場合は null を返す", () => {
    localStorage.setItem("selectedUserId", "invalid");
    expect(loadSelectedUserId()).toBeNull();
  });
});
