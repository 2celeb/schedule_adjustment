/**
 * SchedulePage コンポーネントのユニットテスト
 *
 * 要件: 1.1, 4.3
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import SchedulePage from "@/pages/SchedulePage";
import type { UseGroupResult } from "@/hooks/useGroup";

/** useGroup フックをモック */
const mockUseGroup = vi.fn<(shareToken: string | undefined) => UseGroupResult>();
vi.mock("@/hooks/useGroup", () => ({
  useGroup: (shareToken: string | undefined) => mockUseGroup(shareToken),
}));

/** useCurrentUser フックをモック */
vi.mock("@/hooks/useCurrentUser", () => ({
  useCurrentUser: () => ({
    selectedUserId: null,
    isAuthenticated: false,
    isLoading: false,
    selectUser: vi.fn(),
  }),
}));

/** テスト用グループデータ */
const mockGroup = {
  id: 1,
  name: "サッカーチーム",
  event_name: "サッカーチームの活動",
  locale: "ja",
  timezone: "Asia/Tokyo",
  threshold_n: 3,
  threshold_target: "core" as const,
  default_start_time: "19:00",
  default_end_time: "22:00",
  ad_enabled: true,
};

/** テスト用メンバーデータ */
const mockMembers = [
  {
    id: 1,
    display_name: "えれん",
    discord_screen_name: "eren_discord",
    role: "core" as const,
    auth_locked: false,
  },
  {
    id: 2,
    display_name: "みかさ",
    discord_screen_name: "mikasa_discord",
    role: "core" as const,
    auth_locked: true,
  },
];

/** テスト用の QueryClient ラッパー */
function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        gcTime: 0,
      },
    },
  });
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={["/abc123"]}>
          <Routes>
            <Route path="/:share_token" element={children} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    );
  };
}

describe("SchedulePage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("ローディング中に CircularProgress を表示する", () => {
    mockUseGroup.mockReturnValue({
      group: undefined,
      members: [],
      isLoading: true,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(screen.getByRole("progressbar")).toBeInTheDocument();
    expect(screen.getByText("読み込み中...")).toBeInTheDocument();
  });

  it("エラー時にエラーメッセージを表示する", () => {
    mockUseGroup.mockReturnValue({
      group: undefined,
      members: [],
      isLoading: false,
      isError: true,
      error: new Error("Not Found"),
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(screen.getByText("グループが見つかりません")).toBeInTheDocument();
  });

  it("グループ名とイベント名を表示する", () => {
    mockUseGroup.mockReturnValue({
      group: mockGroup,
      members: mockMembers,
      isLoading: false,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(screen.getByText("サッカーチーム")).toBeInTheDocument();
    expect(screen.getByText("サッカーチームの活動")).toBeInTheDocument();
  });

  it("メンバー選択バーを表示する", () => {
    mockUseGroup.mockReturnValue({
      group: mockGroup,
      members: mockMembers,
      isLoading: false,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(screen.getByText("メンバー選択")).toBeInTheDocument();
    expect(screen.getByText("えれん")).toBeInTheDocument();
    expect(screen.getByText("みかさ")).toBeInTheDocument();
  });

  it("Availability_Board プレースホルダーを表示する", () => {
    mockUseGroup.mockReturnValue({
      group: mockGroup,
      members: mockMembers,
      isLoading: false,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(
      screen.getByTestId("availability-board-placeholder"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("参加可否ボードはここに表示されます"),
    ).toBeInTheDocument();
  });

  it("広告が有効な場合に広告プレースホルダーを表示する", () => {
    mockUseGroup.mockReturnValue({
      group: { ...mockGroup, ad_enabled: true },
      members: mockMembers,
      isLoading: false,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(screen.getByTestId("ad-placeholder")).toBeInTheDocument();
    expect(screen.getByText("広告エリア")).toBeInTheDocument();
  });

  it("広告が無効な場合に広告プレースホルダーを表示しない", () => {
    mockUseGroup.mockReturnValue({
      group: { ...mockGroup, ad_enabled: false },
      members: mockMembers,
      isLoading: false,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(screen.queryByTestId("ad-placeholder")).not.toBeInTheDocument();
  });

  it("share_token を useGroup に渡す", () => {
    mockUseGroup.mockReturnValue({
      group: undefined,
      members: [],
      isLoading: true,
      isError: false,
      error: null,
    });

    render(<SchedulePage />, { wrapper: createWrapper() });

    expect(mockUseGroup).toHaveBeenCalledWith("abc123");
  });
});
