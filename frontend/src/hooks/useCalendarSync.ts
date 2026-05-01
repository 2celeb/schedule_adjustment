/**
 * カレンダー同期状態管理フック
 *
 * TanStack Query で Google カレンダー同期の操作を行う。
 * - POST /api/groups/:share_token/calendar_sync — 強制同期（今すぐ同期）
 * - DELETE /api/users/:userId/google_link — Google 連携解除
 *
 * 要件: 7.1, 7.5, 7.6, 7.11
 */
import { useMutation, useQueryClient } from "@tanstack/react-query";
import apiClient from "@/api/client";

/** useCalendarSync フックの戻り値 */
export interface UseCalendarSyncResult {
  /** 強制同期を実行する関数 */
  triggerSync: (shareToken: string) => void;
  /** Google 連携を解除する関数 */
  disconnectGoogle: (userId: number) => void;
  /** 同期中かどうか */
  isSyncing: boolean;
  /** 連携解除中かどうか */
  isDisconnecting: boolean;
  /** 同期成功フラグ */
  syncSuccess: boolean;
  /** 同期エラー */
  syncError: Error | null;
  /** 連携解除成功フラグ */
  disconnectSuccess: boolean;
  /** 連携解除エラー */
  disconnectError: Error | null;
  /** 同期状態をリセットする */
  resetSyncStatus: () => void;
  /** 連携解除状態をリセットする */
  resetDisconnectStatus: () => void;
}

/**
 * カレンダー同期状態管理フック
 *
 * @returns 同期・連携解除の操作関数とローディング状態
 */
export function useCalendarSync(): UseCalendarSyncResult {
  const queryClient = useQueryClient();

  /** 強制同期ミューテーション */
  const syncMutation = useMutation({
    mutationFn: async (shareToken: string) => {
      await apiClient.post(`/groups/${shareToken}/calendar_sync`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["availabilities"] });
    },
  });

  /** Google 連携解除ミューテーション */
  const disconnectMutation = useMutation({
    mutationFn: async (userId: number) => {
      await apiClient.delete(`/users/${userId}/google_link`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["session"] });
      queryClient.invalidateQueries({ queryKey: ["group"] });
      queryClient.invalidateQueries({ queryKey: ["availabilities"] });
    },
  });

  return {
    triggerSync: (shareToken: string) => syncMutation.mutate(shareToken),
    disconnectGoogle: (userId: number) => disconnectMutation.mutate(userId),
    isSyncing: syncMutation.isPending,
    isDisconnecting: disconnectMutation.isPending,
    syncSuccess: syncMutation.isSuccess,
    syncError: syncMutation.error as Error | null,
    disconnectSuccess: disconnectMutation.isSuccess,
    disconnectError: disconnectMutation.error as Error | null,
    resetSyncStatus: () => syncMutation.reset(),
    resetDisconnectStatus: () => disconnectMutation.reset(),
  };
}
