/**
 * 現在のユーザー識別フック
 *
 * Cookie セッションの有無を確認し、localStorage から選択ユーザー ID を読み込む。
 * TanStack Query で /api/sessions/current エンドポイントを呼び出し、
 * Cookie セッションの有効性を確認する。
 *
 * localStorage が利用不可の場合はインメモリストレージにフォールバックする。
 *
 * 要件: 1.2, 1.3, 1.5
 * 要件: 設計ドキュメント セクション 7.5（localStorage 利用不可時の対応）
 */
import { useState, useCallback, useEffect, useRef } from "react";
import { useQuery } from "@tanstack/react-query";
import apiClient from "@/api/client";
import {
  setStorageItem,
  isStorageAvailable,
} from "@/api/client";
import { useToast } from "@/components/feedback/ToastProvider";
import { useTranslation } from "react-i18next";
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
  /** localStorage が利用可能かどうか */
  storageAvailable: boolean;
}

/** localStorage のキー名 */
const STORAGE_KEY = "selectedUserId";

/**
 * ストレージにユーザー ID を保存する
 * localStorage が使えない場合はインメモリストレージを使用する
 */
function saveToStorage(userId: number): void {
  setStorageItem(STORAGE_KEY, String(userId));
}

/**
 * 現在のユーザー識別フック
 *
 * - localStorage から selectedUserId を読み込み
 * - TanStack Query で /api/sessions/current を呼び出してセッション有効性を確認
 * - Cookie セッションが無効（401）の場合は isAuthenticated: false
 * - localStorage 利用不可時はインメモリ代替 + 注意メッセージ
 */
export function useCurrentUser(): CurrentUserState {
  const { showToast } = useToast();
  const { t } = useTranslation();
  const storageWarningShown = useRef(false);

  /** インメモリのフォールバック（localStorage が使えない場合） */
  const [inMemoryUserId, setInMemoryUserId] = useState<number | null>(() => {
    return loadSelectedUserId();
  });

  const storageAvailable = isStorageAvailable();

  /** localStorage 利用不可時の注意メッセージ（初回のみ） */
  useEffect(() => {
    if (!storageAvailable && !storageWarningShown.current) {
      storageWarningShown.current = true;
      showToast(t("error.localStorageUnavailable"), "warning");
    }
  }, [storageAvailable, showToast, t]);

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
    storageAvailable,
  };
}
