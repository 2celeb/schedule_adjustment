/**
 * 参加可否データ取得・更新フック
 *
 * TanStack Query で参加可否データの取得・キャッシュ管理を行う。
 * - GET /api/groups/:share_token/availabilities?month=YYYY-MM で月単位取得
 * - PUT /api/groups/:share_token/availabilities で一括更新（楽観的更新付き）
 *
 * 要件: 3.1, 3.2, 4.11, 4.12
 */
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import apiClient from "@/api/client";
import type {
  AvailabilitiesMap,
  AvailabilityEntry,
  EventDaysMap,
  SummaryMap,
} from "@/types/availability";
import type { AvailabilityStatus } from "@/utils/availabilitySymbols";

/** API レスポンスの型 */
interface AvailabilitiesResponse {
  availabilities: AvailabilitiesMap;
  event_days: EventDaysMap;
  summary: SummaryMap;
}

/** ミューテーション用パラメータ */
interface UpdateAvailabilityParams {
  userId: number;
  date: string;
  status: AvailabilityStatus;
  comment: string | null;
}

/** useAvailabilities フックの戻り値 */
export interface UseAvailabilitiesResult {
  /** 参加可否データ */
  availabilities: AvailabilitiesMap;
  /** 活動日データ */
  eventDays: EventDaysMap;
  /** 集計データ */
  summary: SummaryMap;
  /** ローディング中かどうか */
  isLoading: boolean;
  /** エラーが発生したかどうか */
  isError: boolean;
  /** 参加可否を更新する関数 */
  updateAvailability: (params: UpdateAvailabilityParams) => void;
}

/**
 * status を次の値にサイクルする
 * null → 1 → 0 → -1 → null
 */
export function cycleStatus(current: AvailabilityStatus): AvailabilityStatus {
  switch (current) {
    case null:
      return 1;
    case 1:
      return 0;
    case 0:
      return -1;
    case -1:
      return null;
    default:
      return null;
  }
}

/**
 * 参加可否データ取得・更新フック
 *
 * @param shareToken - グループの共有トークン
 * @param month - 対象月（YYYY-MM 形式）
 * @returns 参加可否データ、活動日、集計、更新関数
 */
export function useAvailabilities(
  shareToken: string | undefined,
  month: string,
): UseAvailabilitiesResult {
  const queryClient = useQueryClient();
  const queryKey = ["availabilities", shareToken, month];

  /** データ取得 */
  const { data, isLoading, isError } = useQuery<AvailabilitiesResponse>({
    queryKey,
    queryFn: async () => {
      const response = await apiClient.get<AvailabilitiesResponse>(
        `/groups/${shareToken}/availabilities`,
        { params: { month } },
      );
      return response.data;
    },
    enabled: !!shareToken,
  });

  /** 楽観的更新付きミューテーション */
  const mutation = useMutation({
    mutationFn: async (params: UpdateAvailabilityParams) => {
      await apiClient.put(`/groups/${shareToken}/availabilities`, {
        user_id: params.userId,
        availabilities: [
          {
            date: params.date,
            status: params.status,
            comment: params.comment,
          },
        ],
      });
    },
    onMutate: async (params: UpdateAvailabilityParams) => {
      /* 進行中のクエリをキャンセル */
      await queryClient.cancelQueries({ queryKey });

      /* 現在のキャッシュを保存（ロールバック用） */
      const previousData =
        queryClient.getQueryData<AvailabilitiesResponse>(queryKey);

      /* 楽観的にキャッシュを更新 */
      queryClient.setQueryData<AvailabilitiesResponse>(queryKey, (old) => {
        if (!old) return old;

        const newAvailabilities = { ...old.availabilities };
        const dateEntries = { ...(newAvailabilities[params.date] ?? {}) };
        const userKey = String(params.userId);

        const existingEntry = dateEntries[userKey];
        const newEntry: AvailabilityEntry = {
          status: params.status,
          comment: params.comment,
          auto_synced: existingEntry?.auto_synced ?? false,
        };
        dateEntries[userKey] = newEntry;
        newAvailabilities[params.date] = dateEntries;

        return {
          ...old,
          availabilities: newAvailabilities,
        };
      });

      return { previousData };
    },
    onError: (_error, _params, context) => {
      /* エラー時はロールバック */
      if (context?.previousData) {
        queryClient.setQueryData(queryKey, context.previousData);
      }
    },
    onSettled: () => {
      /* 成功・失敗に関わらずキャッシュを無効化して最新データを取得 */
      queryClient.invalidateQueries({ queryKey });
    },
  });

  /** 参加可否を更新する */
  const updateAvailability = (params: UpdateAvailabilityParams) => {
    mutation.mutate(params);
  };

  return {
    availabilities: data?.availabilities ?? {},
    eventDays: data?.event_days ?? {},
    summary: data?.summary ?? {},
    isLoading,
    isError,
    updateAvailability,
  };
}
