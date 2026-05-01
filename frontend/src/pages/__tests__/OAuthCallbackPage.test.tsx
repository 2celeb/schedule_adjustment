/**
 * OAuthCallbackPage コンポーネントのユニットテスト
 *
 * 要件: 1.4, 1.5
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import OAuthCallbackPage from "@/pages/OAuthCallbackPage";

/** react-router-dom の useNavigate をモック */
const mockNavigate = vi.fn();
vi.mock("react-router-dom", async () => {
  const actual = await vi.importActual("react-router-dom");
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

describe("OAuthCallbackPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("成功時にリダイレクトメッセージを表示する", () => {
    render(
      <MemoryRouter initialEntries={["/oauth/callback"]}>
        <OAuthCallbackPage />
      </MemoryRouter>,
    );
    expect(
      screen.getByText("認証に成功しました。リダイレクトしています..."),
    ).toBeInTheDocument();
  });

  it("成功時にローディングスピナーを表示する", () => {
    render(
      <MemoryRouter initialEntries={["/oauth/callback"]}>
        <OAuthCallbackPage />
      </MemoryRouter>,
    );
    expect(screen.getByRole("progressbar")).toBeInTheDocument();
  });

  it("エラーパラメータがある場合にエラーメッセージを表示する", () => {
    render(
      <MemoryRouter initialEntries={["/oauth/callback?error=auth_failed"]}>
        <OAuthCallbackPage />
      </MemoryRouter>,
    );
    expect(screen.getByText("auth_failed")).toBeInTheDocument();
  });

  it("409 エラーの場合に Google アカウント競合メッセージを表示する", () => {
    render(
      <MemoryRouter
        initialEntries={["/oauth/callback?error=conflict&error_code=409"]}
      >
        <OAuthCallbackPage />
      </MemoryRouter>,
    );
    expect(
      screen.getByText("別の Google アカウントで連携済みです"),
    ).toBeInTheDocument();
  });

  it("エラー時にトップページに戻るボタンを表示する", () => {
    render(
      <MemoryRouter initialEntries={["/oauth/callback?error=auth_failed"]}>
        <OAuthCallbackPage />
      </MemoryRouter>,
    );
    expect(
      screen.getByText("トップページに戻る"),
    ).toBeInTheDocument();
  });

  it("トップページに戻るボタンをクリックするとナビゲートする", async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter initialEntries={["/oauth/callback?error=auth_failed"]}>
        <OAuthCallbackPage />
      </MemoryRouter>,
    );
    await user.click(screen.getByText("トップページに戻る"));
    expect(mockNavigate).toHaveBeenCalledWith("/", { replace: true });
  });
});
