/**
 * useAvailabilities フックのユニットテスト
 *
 * 要件: 3.1, 3.2, 4.11, 4.12
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useAvailabilities, cycleStatus } from "@/hooks/useAvailabilities";
import apiClient from "@/api/client";

/** apiClient をモック */
vi.mock("@/api/client", () => ({
  default: {
    get: vi.fn(),
    put: vi.fn(),
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

/** テスト用レスポンスデータ */
const mockResponse = {
  availabilities: {
    "2025-01-15": {
      "1": { status: 1, comment: null, auto_synced: false },
      "2": { status: -1, comment: "出張", auto_synced: false },
    },
  },
  event_days: {
    "2025-01-20": {
      start_time: "19:00",
      end_time: "22:00",
      confirmed: true,
      custom_time: false,
    },
  },
  summary: {
    "2025-01-15": { ok: 1, maybe: 0, ng: 1, none: 0 },
  },
};

describe("useAvailabilities", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("参加可否データを取得する", async () => {
    mockedApiClient.get.mockResolvedValueOnce({ data: mockResponse });

    const { result } = renderHook(
      () => useAvailabilities("abc123", "2025-01"),
      { wrapper: createWrapper() },
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.availabilities).toEqual(mockResponse.availabilities);
    expect(result.current.eventDays).toEqual(mockResponse.event_days);
    expect(result.current.summary).toEqual(mockResponse.summary);
    expect(result.current.isError).toBe(false);
    expect(mockedApiClient.get).toHaveBeenCalledWith(
      "/groups/abc123/availabilities",
      { params: { month: "2025-01" } },
    );
  });

  it("shareToken が undefined の場合はクエリを実行しない", () => {
    renderHook(() => useAvailabilities(undefined, "2025-01"), {
      wrapper: createWrapper(),
    });

    expect(mockedApiClient.get).not.toHaveBeenCalled();
  });

  it("API エラー時に isError が true になる", async () => {
    mockedApiClient.get.mockRejectedValueOnce(new Error("Network Error"));

    const { result } = renderHook(
      () => useAvailabilities("abc123", "2025-01"),
      { wrapper: createWrapper() },
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.isError).toBe(true);
    expect(result.current.availabilities).toEqual({});
  });

  it("updateAvailability で PUT リクエストを送信する", async () => {
    mockedApiClient.get.mockResolvedValue({ data: mockResponse });
    mockedApiClient.put.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(
      () => useAvailabilities("abc123", "2025-01"),
      { wrapper: createWrapper() },
    );

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.updateAvailability({
        userId: 1,
        date: "2025-01-15",
        status: 0,
        comment: null,
      });
    });

    await waitFor(() => {
      expect(mockedApiClient.put).toHaveBeenCalledWith(
        "/groups/abc123/availabilities",
        {
          user_id: 1,
          availabilities: [
            { date: "2025-01-15", status: 0, comment: null },
          ],
        },
      );
    });
  });

  it("データ未取得時はデフォルト値を返す", () => {
    mockedApiClient.get.mockReturnValue(new Promise(() => {}));

    const { result } = renderHook(
      () => useAvailabilities("abc123", "2025-01"),
      { wrapper: createWrapper() },
    );

    expect(result.current.availabilities).toEqual({});
    expect(result.current.eventDays).toEqual({});
    expect(result.current.summary).toEqual({});
    expect(result.current.isLoading).toBe(true);
  });
});

describe("cycleStatus", () => {
  it("null → 1 にサイクルする", () => {
    expect(cycleStatus(null)).toBe(1);
  });

  it("1 → 0 にサイクルする", () => {
    expect(cycleStatus(1)).toBe(0);
  });

  it("0 → -1 にサイクルする", () => {
    expect(cycleStatus(0)).toBe(-1);
  });

  it("-1 → null にサイクルする", () => {
    expect(cycleStatus(-1)).toBeNull();
  });
});
