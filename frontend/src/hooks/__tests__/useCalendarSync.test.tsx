/**
 * useCalendarSync フックのユニットテスト
 *
 * 要件: 7.1, 7.5, 7.6, 7.11
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useCalendarSync } from "@/hooks/useCalendarSync";
import apiClient from "@/api/client";

/** apiClient をモック */
vi.mock("@/api/client", () => ({
  default: {
    post: vi.fn(),
    delete: vi.fn(),
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

describe("useCalendarSync", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("初期状態では isSyncing と isDisconnecting が false", () => {
    const { result } = renderHook(() => useCalendarSync(), {
      wrapper: createWrapper(),
    });

    expect(result.current.isSyncing).toBe(false);
    expect(result.current.isDisconnecting).toBe(false);
    expect(result.current.syncSuccess).toBe(false);
    expect(result.current.disconnectSuccess).toBe(false);
  });

  it("triggerSync が正しいエンドポイントを呼び出す", async () => {
    mockedApiClient.post.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useCalendarSync(), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.triggerSync("abc123");
    });

    await waitFor(() => {
      expect(mockedApiClient.post).toHaveBeenCalledWith(
        "/groups/abc123/calendar_sync",
      );
    });

    await waitFor(() => {
      expect(result.current.syncSuccess).toBe(true);
    });
  });

  it("disconnectGoogle が正しいエンドポイントを呼び出す", async () => {
    mockedApiClient.delete.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useCalendarSync(), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.disconnectGoogle(42);
    });

    await waitFor(() => {
      expect(mockedApiClient.delete).toHaveBeenCalledWith(
        "/users/42/google_link",
      );
    });

    await waitFor(() => {
      expect(result.current.disconnectSuccess).toBe(true);
    });
  });

  it("triggerSync 失敗時に syncError が設定される", async () => {
    mockedApiClient.post.mockRejectedValueOnce(new Error("Network Error"));

    const { result } = renderHook(() => useCalendarSync(), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.triggerSync("abc123");
    });

    await waitFor(() => {
      expect(result.current.syncError).toBeTruthy();
    });

    expect(result.current.syncSuccess).toBe(false);
  });

  it("disconnectGoogle 失敗時に disconnectError が設定される", async () => {
    mockedApiClient.delete.mockRejectedValueOnce(new Error("Forbidden"));

    const { result } = renderHook(() => useCalendarSync(), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.disconnectGoogle(42);
    });

    await waitFor(() => {
      expect(result.current.disconnectError).toBeTruthy();
    });

    expect(result.current.disconnectSuccess).toBe(false);
  });

  it("resetSyncStatus で同期状態をリセットできる", async () => {
    mockedApiClient.post.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useCalendarSync(), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.triggerSync("abc123");
    });

    await waitFor(() => {
      expect(result.current.syncSuccess).toBe(true);
    });

    act(() => {
      result.current.resetSyncStatus();
    });

    await waitFor(() => {
      expect(result.current.syncSuccess).toBe(false);
    });
  });
});
