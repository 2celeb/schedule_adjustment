/**
 * グループ情報取得フック
 *
 * TanStack Query で GET /api/groups/:share_token を呼び出し、
 * グループ情報とメンバー一覧を取得する。
 *
 * 要件: 1.1
 */
import { useQuery } from "@tanstack/react-query";
import apiClient from "@/api/client";
import type { Group } from "@/types/group";
import type { Member } from "@/types/member";

/** API レスポンスの型 */
interface GroupResponse {
  group: Group;
  members: Member[];
}

/** useGroup フックの戻り値 */
export interface UseGroupResult {
  /** グループ情報 */
  group: Group | undefined;
  /** メンバー一覧 */
  members: Member[];
  /** ローディング中かどうか */
  isLoading: boolean;
  /** エラーが発生したかどうか */
  isError: boolean;
  /** エラーオブジェクト */
  error: Error | null;
}

/**
 * グループ情報取得フック
 *
 * @param shareToken - グループの共有トークン
 * @returns グループ情報、メンバー一覧、ローディング・エラー状態
 */
export function useGroup(shareToken: string | undefined): UseGroupResult {
  const {
    data,
    isLoading,
    isError,
    error,
  } = useQuery<GroupResponse>({
    queryKey: ["group", shareToken],
    queryFn: async () => {
      const response = await apiClient.get<GroupResponse>(
        `/groups/${shareToken}`,
      );
      return response.data;
    },
    /** shareToken が存在する場合のみクエリを実行 */
    enabled: !!shareToken,
  });

  return {
    group: data?.group,
    members: data?.members ?? [],
    isLoading,
    isError,
    error: error as Error | null,
  };
}
