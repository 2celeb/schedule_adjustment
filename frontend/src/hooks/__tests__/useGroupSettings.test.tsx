/**
 * useGroupSettings フックのユニットテスト
 *
 * 要件: 5.2, 5.3, 5.9
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useAutoScheduleRule, useEventDays, useGroupUpdate } from "@/hooks/useGroupSettings";
import apiClient from "@/api/client";

/** apiClient をモック */
vi.mock("@/api/client", () => ({
  default: {
    get: vi.fn(),
    put: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
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

/** テスト用ルールデータ */
const mockRuleResponse = {
  auto_schedule_rule: {
    id: 1,
    group_id: 1,
    max_days_per_week: 3,
    min_days_per_week: 1,
    deprioritized_days: [0, 6],
    excluded_days: [0],
    week_start_day: 1,
    confirm_days_before: 3,
    remind_days_before_confirm: 2,
    confirm_time: "21:00",
    activity_notify_hours_before: 8,
    activity_notify_channel_id: null,
    activity_notify_message: null,
  },
};

/** テスト用活動日データ */
const mockEventDaysResponse = {
  event_days: [
    {
      id: 1,
      group_id: 1,
      date: "2026-05-05",
      start_time: "19:00",
      end_time: "22:00",
      auto_generated: false,
      confirmed: true,
      confirmed_at: "2026-05-01T12:00:00Z",
      custom_time: false,
    },
    {
      id: 2,
      group_id: 1,
      date: "2026-05-12",
      start_time: "18:00",
      end_time: "21:00",
      auto_generated: true,
      confirmed: false,
      confirmed_at: null,
      custom_time: true,
    },
  ],
};

describe("useAutoScheduleRule", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("グループ ID でルールを取得する", async () => {
    mockedApiClient.get.mockResolvedValueOnce({ data: mockRuleResponse });

    const { result } = renderHook(() => useAutoScheduleRule(1), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.rule).toEqual(mockRuleResponse.auto_schedule_rule);
    expect(result.current.isError).toBe(false);
    expect(mockedApiClient.get).toHaveBeenCalledWith(
      "/groups/1/auto_schedule_rule",
    );
  });

  it("groupId が undefined の場合はクエリを実行しない", () => {
    renderHook(() => useAutoScheduleRule(undefined), {
      wrapper: createWrapper(),
    });

    expect(mockedApiClient.get).not.toHaveBeenCalled();
  });

  it("ルールを更新できる", async () => {
    mockedApiClient.get.mockResolvedValueOnce({ data: mockRuleResponse });
    mockedApiClient.put.mockResolvedValueOnce({ data: mockRuleResponse });

    const { result } = renderHook(() => useAutoScheduleRule(1), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.updateRule({ max_days_per_week: 5 });
    });

    await waitFor(() => {
      expect(mockedApiClient.put).toHaveBeenCalledWith(
        "/groups/1/auto_schedule_rule",
        { max_days_per_week: 5 },
      );
    });
  });
});

describe("useEventDays", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("グループ ID と月で活動日を取得する", async () => {
    mockedApiClient.get.mockResolvedValueOnce({
      data: mockEventDaysResponse,
    });

    const { result } = renderHook(() => useEventDays(1, "2026-05"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.eventDays).toEqual(
      mockEventDaysResponse.event_days,
    );
    expect(result.current.isError).toBe(false);
    expect(mockedApiClient.get).toHaveBeenCalledWith(
      "/groups/1/event_days",
      { params: { month: "2026-05" } },
    );
  });

  it("groupId が undefined の場合はクエリを実行しない", () => {
    renderHook(() => useEventDays(undefined, "2026-05"), {
      wrapper: createWrapper(),
    });

    expect(mockedApiClient.get).not.toHaveBeenCalled();
  });

  it("活動日を追加できる", async () => {
    mockedApiClient.get.mockResolvedValueOnce({
      data: mockEventDaysResponse,
    });
    mockedApiClient.post.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useEventDays(1, "2026-05"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.addEventDay({ date: "2026-05-20" });
    });

    await waitFor(() => {
      expect(mockedApiClient.post).toHaveBeenCalledWith(
        "/groups/1/event_days",
        { date: "2026-05-20" },
      );
    });
  });

  it("活動日を更新できる", async () => {
    mockedApiClient.get.mockResolvedValueOnce({
      data: mockEventDaysResponse,
    });
    mockedApiClient.patch.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useEventDays(1, "2026-05"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.updateEventDay({
        id: 1,
        start_time: "18:00",
        end_time: "21:00",
      });
    });

    await waitFor(() => {
      expect(mockedApiClient.patch).toHaveBeenCalledWith("/event_days/1", {
        start_time: "18:00",
        end_time: "21:00",
      });
    });
  });

  it("活動日を削除できる", async () => {
    mockedApiClient.get.mockResolvedValueOnce({
      data: mockEventDaysResponse,
    });
    mockedApiClient.delete.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useEventDays(1, "2026-05"), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    act(() => {
      result.current.deleteEventDay(1);
    });

    await waitFor(() => {
      expect(mockedApiClient.delete).toHaveBeenCalledWith("/event_days/1");
    });
  });
});

describe("useGroupUpdate", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("グループ設定を更新できる", async () => {
    mockedApiClient.patch.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useGroupUpdate(1, "abc123"), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.updateGroup({ name: "新しいグループ名" });
    });

    await waitFor(() => {
      expect(mockedApiClient.patch).toHaveBeenCalledWith("/groups/1", {
        name: "新しいグループ名",
      });
    });
  });

  it("groupId が undefined の場合でも関数は呼び出せる", () => {
    const { result } = renderHook(() => useGroupUpdate(undefined, undefined), {
      wrapper: createWrapper(),
    });

    expect(result.current.isUpdating).toBe(false);
    expect(result.current.isError).toBe(false);
  });

  it("閾値設定を更新できる", async () => {
    mockedApiClient.patch.mockResolvedValueOnce({ data: {} });

    const { result } = renderHook(() => useGroupUpdate(1, "abc123"), {
      wrapper: createWrapper(),
    });

    act(() => {
      result.current.updateGroup({
        threshold_n: 5,
        threshold_target: "all",
      });
    });

    await waitFor(() => {
      expect(mockedApiClient.patch).toHaveBeenCalledWith("/groups/1", {
        threshold_n: 5,
        threshold_target: "all",
      });
    });
  });
});
