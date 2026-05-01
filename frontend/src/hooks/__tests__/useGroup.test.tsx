/**
 * useGroup フックのユニットテスト
 *
 * 要件: 1.1
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useGroup } from "@/hooks/useGroup";
import apiClient from "@/api/client";

/** apiClient をモック */
vi.mock("@/api/client", () => ({
  default: {
    get: vi.fn(),
  },
}));

const mockedApiClient = vi.mocked(apiClient);

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

/** テスト用グループデータ */
const mockGroupResponse = {
  group: {
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
  },
  members: [
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
  ],
};

describe("useGroup", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("share_token でグループ情報を取得する", async () => {
    mockedApiClient.get.mockResolvedValueOnce({ data: mockGroupResponse });

    const { result } = renderHook(() => useGroup("abc123"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.group).toEqual(mockGroupResponse.group);
    expect(result.current.members).toEqual(mockGroupResponse.members);
    expect(result.current.isError).toBe(false);
    expect(mockedApiClient.get).toHaveBeenCalledWith("/groups/abc123");
  });

  it("API エラー時に isError が true になる", async () => {
    mockedApiClient.get.mockRejectedValueOnce(new Error("Network Error"));

    const { result } = renderHook(() => useGroup("invalid_token"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.isError).toBe(true);
    expect(result.current.error).toBeInstanceOf(Error);
    expect(result.current.group).toBeUndefined();
    expect(result.current.members).toEqual([]);
  });

  it("share_token が undefined の場合はクエリを実行しない", () => {
    renderHook(() => useGroup(undefined), {
      wrapper: createWrapper(),
    });

    expect(mockedApiClient.get).not.toHaveBeenCalled();
  });

  it("ローディング中は isLoading が true", () => {
    mockedApiClient.get.mockReturnValue(new Promise(() => {}));

    const { result } = renderHook(() => useGroup("abc123"), {
      wrapper: createWrapper(),
    });

    expect(result.current.isLoading).toBe(true);
    expect(result.current.group).toBeUndefined();
    expect(result.current.members).toEqual([]);
  });
});
