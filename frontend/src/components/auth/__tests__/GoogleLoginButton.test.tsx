/**
 * GoogleLoginButton コンポーネントのユニットテスト
 *
 * 要件: 1.4, 1.5
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import GoogleLoginButton from "@/components/auth/GoogleLoginButton";

describe("GoogleLoginButton", () => {
  it("Google でログインボタンを表示する", () => {
    render(<GoogleLoginButton />);
    expect(screen.getByText("Google でログイン")).toBeInTheDocument();
  });

  it("カスタム onClick コールバックが呼ばれる", async () => {
    const handleClick = vi.fn();
    const user = userEvent.setup();
    render(<GoogleLoginButton onClick={handleClick} />);
    await user.click(screen.getByText("Google でログイン"));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it("loading=true の場合はローディング表示になる", () => {
    render(<GoogleLoginButton loading={true} />);
    expect(screen.getByText("読み込み中...")).toBeInTheDocument();
    expect(screen.getByRole("progressbar")).toBeInTheDocument();
  });

  it("loading=true の場合はボタンが無効化される", () => {
    render(<GoogleLoginButton loading={true} />);
    const button = screen.getByRole("button");
    expect(button).toBeDisabled();
  });

  it("disabled=true の場合はボタンが無効化される", () => {
    render(<GoogleLoginButton disabled={true} />);
    const button = screen.getByRole("button");
    expect(button).toBeDisabled();
  });

  it("disabled=false かつ loading=false の場合はボタンが有効", () => {
    render(<GoogleLoginButton disabled={false} loading={false} />);
    const button = screen.getByRole("button");
    expect(button).not.toBeDisabled();
  });

  it("onClick 未指定の場合はデフォルトで OAuth エンドポイントにリダイレクトする", async () => {
    /** window.location.href のモック */
    const originalLocation = window.location;
    const mockLocation = { ...originalLocation, href: "" };
    Object.defineProperty(window, "location", {
      value: mockLocation,
      writable: true,
    });

    const user = userEvent.setup();
    render(<GoogleLoginButton />);
    await user.click(screen.getByText("Google でログイン"));
    expect(mockLocation.href).toBe("/oauth/google");

    /** モックを元に戻す */
    Object.defineProperty(window, "location", {
      value: originalLocation,
      writable: true,
    });
  });
});
