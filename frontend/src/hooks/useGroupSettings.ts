/**
 * グループ設定データの取得・更新フック
 *
 * TanStack Query で自動確定ルールと活動日の取得・更新を行う。
 * - GET /api/groups/:id/auto_schedule_rule でルール取得
 * - PUT /api/groups/:id/auto_schedule_rule でルール更新
 * - GET /api/groups/:id/event_days で活動日取得
 * - POST /api/groups/:id/event_days で活動日追加
 * - PATCH /api/event_days/:id で活動日更新
 * - DELETE /api/event_days/:id で活動日削除
 *
 * 要件: 5.2, 5.3, 5.9
 */
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import apiClient from "@/api/client";

/** 自動確定ルールの型 */
export interface AutoScheduleRule {
  id: number | null;
  group_id: number;
  max_days_per_week: number | null;
  min_days_per_week: number | null;
  deprioritized_days: number[];
  excluded_days: number[];
  week_start_day: number;
  confirm_days_before: number;
  remind_days_before_confirm: number;
  confirm_time: string | null;
  activity_notify_hours_before: number;
  activity_notify_channel_id: string | null;
  activity_notify_message: string | null;
}

/** 活動日の型 */
export interface EventDay {
  id: number;
  group_id: number;
  date: string;
  start_time: string | null;
  end_time: string | null;
  auto_generated: boolean;
  confirmed: boolean;
  confirmed_at: string | null;
  custom_time: boolean;
}

/** ルール更新パラメータ */
export interface UpdateRuleParams {
  max_days_per_week?: number | null;
  min_days_per_week?: number | null;
  deprioritized_days?: number[];
  excluded_days?: number[];
  week_start_day?: number;
  confirm_days_before?: number;
  confirm_time?: string;
  remind_days_before_confirm?: number | null;
  activity_notify_hours_before?: number | null;
  activity_notify_channel_id?: string | null;
  activity_notify_message?: string | null;
}

/** 活動日追加パラメータ */
export interface CreateEventDayParams {
  date: string;
  start_time?: string;
  end_time?: string;
  confirmed?: boolean;
}

/** 活動日更新パラメータ */
export interface UpdateEventDayParams {
  id: number;
  start_time?: string;
  end_time?: string;
  confirmed?: boolean;
}

/** useAutoScheduleRule フックの戻り値 */
export interface UseAutoScheduleRuleResult {
  rule: AutoScheduleRule | undefined;
  isLoading: boolean;
  isError: boolean;
  updateRule: (params: UpdateRuleParams) => void;
  isUpdating: boolean;
}

/** useEventDays フックの戻り値 */
export interface UseEventDaysResult {
  eventDays: EventDay[];
  isLoading: boolean;
  isError: boolean;
  addEventDay: (params: CreateEventDayParams) => void;
  updateEventDay: (params: UpdateEventDayParams) => void;
  deleteEventDay: (id: number) => void;
  isAdding: boolean;
}

/**
 * 自動確定ルール取得・更新フック
 *
 * @param groupId - グループ ID
 * @returns ルールデータ、更新関数、ローディング状態
 */
export function useAutoScheduleRule(
  groupId: number | undefined,
): UseAutoScheduleRuleResult {
  const queryClient = useQueryClient();
  const queryKey = ["autoScheduleRule", groupId];

  const { data, isLoading, isError } = useQuery<{
    auto_schedule_rule: AutoScheduleRule;
  }>({
    queryKey,
    queryFn: async () => {
      const response = await apiClient.get(
        `/groups/${groupId}/auto_schedule_rule`,
      );
      return response.data;
    },
    enabled: !!groupId,
  });

  const mutation = useMutation({
    mutationFn: async (params: UpdateRuleParams) => {
      await apiClient.put(`/groups/${groupId}/auto_schedule_rule`, params);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey });
    },
  });

  return {
    rule: data?.auto_schedule_rule,
    isLoading,
    isError,
    updateRule: (params: UpdateRuleParams) => mutation.mutate(params),
    isUpdating: mutation.isPending,
  };
}

/** グループ設定更新パラメータ */
export interface UpdateGroupParams {
  name?: string;
  event_name?: string;
  default_start_time?: string | null;
  default_end_time?: string | null;
  timezone?: string;
  locale?: string;
  threshold_n?: number | null;
  threshold_target?: "core" | "all";
}

/** useGroupUpdate フックの戻り値 */
export interface UseGroupUpdateResult {
  updateGroup: (params: UpdateGroupParams) => void;
  isUpdating: boolean;
  isError: boolean;
}

/**
 * グループ設定更新フック
 *
 * PATCH /api/groups/:id でグループ基本設定を更新する。
 *
 * @param groupId - グループ ID
 * @param shareToken - グループの共有トークン（キャッシュ無効化用）
 * @returns 更新関数、ローディング・エラー状態
 */
export function useGroupUpdate(
  groupId: number | undefined,
  shareToken: string | undefined,
): UseGroupUpdateResult {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: async (params: UpdateGroupParams) => {
      await apiClient.patch(`/groups/${groupId}`, params);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["group", shareToken] });
    },
  });

  return {
    updateGroup: (params: UpdateGroupParams) => mutation.mutate(params),
    isUpdating: mutation.isPending,
    isError: mutation.isError,
  };
}

/**
 * 活動日取得・管理フック
 *
 * @param groupId - グループ ID
 * @param month - 対象月（YYYY-MM 形式）
 * @returns 活動日データ、追加・更新・削除関数
 */
export function useEventDays(
  groupId: number | undefined,
  month: string,
): UseEventDaysResult {
  const queryClient = useQueryClient();
  const queryKey = ["eventDays", groupId, month];

  const { data, isLoading, isError } = useQuery<{ event_days: EventDay[] }>({
    queryKey,
    queryFn: async () => {
      const response = await apiClient.get(
        `/groups/${groupId}/event_days`,
        { params: { month } },
      );
      return response.data;
    },
    enabled: !!groupId,
  });

  const addMutation = useMutation({
    mutationFn: async (params: CreateEventDayParams) => {
      await apiClient.post(`/groups/${groupId}/event_days`, params);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey });
      queryClient.invalidateQueries({ queryKey: ["availabilities"] });
    },
  });

  const updateMutation = useMutation({
    mutationFn: async (params: UpdateEventDayParams) => {
      const { id, ...rest } = params;
      await apiClient.patch(`/event_days/${id}`, rest);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey });
      queryClient.invalidateQueries({ queryKey: ["availabilities"] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: number) => {
      await apiClient.delete(`/event_days/${id}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey });
      queryClient.invalidateQueries({ queryKey: ["availabilities"] });
    },
  });

  return {
    eventDays: data?.event_days ?? [],
    isLoading,
    isError,
    addEventDay: (params: CreateEventDayParams) => addMutation.mutate(params),
    updateEventDay: (params: UpdateEventDayParams) =>
      updateMutation.mutate(params),
    deleteEventDay: (id: number) => deleteMutation.mutate(id),
    isAdding: addMutation.isPending,
  };
}
