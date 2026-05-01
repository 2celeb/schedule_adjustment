/**
 * 現在のユーザー識別フック
 *
 * Cookie セッションの有無を確認し、localStorage から選択ユーザー ID を読み込む。
 * TanStack Query で /api/sessions/current エンドポイントを呼び出し、
 * Cookie セッションの有効性を確認する。
 *
 * 要件: 1.2, 1.3, 1.5
 */
import { useState, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import apiClient from "@/api/client";
import { loadSelectedUserId } from "@/components/members/MemberSelector";

/** 現在のユーザー状態 */
export interface CurrentUserState {
  /** 選択中のユーザー ID（localStorage から） */
  selectedUserId: number | null;
  /** Cookie セッションが有効かどうか */
  isAuthenticated: boolean;
  /** セッション確認中かどうか */
  isLoading: boolean;
  /** ユーザー選択を変更する関数 */
  selectUser: (userId: number) => void;
}

/** localStorage のキー名 */
const STORAGE_KEY = "selectedUserId";

/**
 * localStorage にユーザー ID を保存する
 * localStorage が使えない場合は無視する
 */
function saveToStorage(userId: number): void {
  try {
    localStorage.setItem(STORAGE_KEY, String(userId));
  } catch {
    /* シークレットモード等で localStorage が使えない場合は無視 */
  }
}

/**
 * 現在のユーザー識別フック
 *
 * - localStorage から selectedUserId を読み込み
 * - TanStack Query で /api/sessions/current を呼び出してセッション有効性を確認
 * - Cookie セッションが無効（401）の場合は isAuthenticated: false
 */
export function useCurrentUser(): CurrentUserState {
  /** インメモリのフォールバック（localStorage が使えない場合） */
  const [inMemoryUserId, setInMemoryUserId] = useState<number | null>(() => {
    return loadSelectedUserId();
  });

  /** セッション有効性の確認 */
  const { data: isAuthenticated = false, isLoading } = useQuery({
    queryKey: ["session", "current"],
    queryFn: async () => {
      try {
        await apiClient.get("/sessions/current");
        return true;
      } catch {
        /* 401 等のエラーの場合はセッション無効 */
        return false;
      }
    },
    /** セッション確認は5分間キャッシュ */
    staleTime: 5 * 60 * 1000,
    /** リトライしない（401 は正常なレスポンス） */
    retry: false,
  });

  /** ユーザー選択を変更する */
  const selectUser = useCallback((userId: number) => {
    saveToStorage(userId);
    setInMemoryUserId(userId);
  }, []);

  return {
    selectedUserId: inMemoryUserId,
    isAuthenticated,
    isLoading,
    selectUser,
  };
}
