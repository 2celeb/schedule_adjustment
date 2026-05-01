/**
 * useCurrentUser フックのユニットテスト
 *
 * 要件: 1.2, 1.3, 1.5
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useCurrentUser } from "@/hooks/useCurrentUser";
import apiClient from "@/api/client";

/** apiClient をモック */
vi.mock("@/api/client", () => ({
  default: {
    get: vi.fn(),
  },
}));

const mockedApiClient = vi.mocked(apiClient, true);

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
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    );
  };
}

describe("useCurrentUser", () => {
  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  it("localStorage から selectedUserId を読み込む", () => {
    localStorage.setItem("selectedUserId", "42");
    const { result } = renderHook(() => useCurrentUser(), {
      wrapper: createWrapper(),
    });
    expect(result.current.selectedUserId).toBe(42);
  });

  it("localStorage に値がない場合は selectedUserId が null", () => {
    const { result } = renderHook(() => useCurrentUser(), {
      wrapper: createWrapper(),
    });
    expect(result.current.selectedUserId).toBeNull();
  });

  it("セッションが有効な場合は isAuthenticated が true", async () => {
    mockedApiClient.get.mockResolvedValueOnce({ data: { user_id: 1 } });
    const { result } = renderHook(() => useCurrentUser(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
    expect(result.current.isAuthenticated).toBe(true);
  });

  it("セッションが無効（401）の場合は isAuthenticated が false", async () => {
    mockedApiClient.get.mockRejectedValueOnce({ response: { status: 401 } });
    const { result } = renderHook(() => useCurrentUser(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
    expect(result.current.isAuthenticated).toBe(false);
  });

  it("selectUser でユーザー ID を変更できる", () => {
    const { result } = renderHook(() => useCurrentUser(), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.selectUser(99);
    });

    expect(result.current.selectedUserId).toBe(99);
    expect(localStorage.getItem("selectedUserId")).toBe("99");
  });

  it("初期状態で isLoading が true", () => {
    mockedApiClient.get.mockReturnValue(new Promise(() => {}));
    const { result } = renderHook(() => useCurrentUser(), {
      wrapper: createWrapper(),
    });
    expect(result.current.isLoading).toBe(true);
  });
});
