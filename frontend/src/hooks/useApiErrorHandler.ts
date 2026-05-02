/**
 * API エラーハンドリングフック
 *
 * TanStack Query の onError コールバックと組み合わせて使用する。
 * エラーの種類に応じてトースト通知を表示し、
 * 401 エラーの場合は再ログインボタンを表示する。
 *
 * 使用方法:
 *   const { handleError } = useApiErrorHandler();
 *   const mutation = useMutation({
 *     mutationFn: ...,
 *     onError: handleError,
 *   });
 *
 * 要件: 設計ドキュメント セクション 7.5
 */
import { useCallback } from "react";
import { useToast } from "@/components/feedback/ToastProvider";
import { parseApiError } from "@/utils/apiErrors";

export function useApiErrorHandler() {
  const { showToast } = useToast();

  /**
   * API エラーをハンドリングする
   * エラーの種類に応じてトースト通知を表示する
   */
  const handleError = useCallback(
    (error: unknown) => {
      const parsed = parseApiError(error);

      if (parsed.requiresReauth) {
        showToast(parsed.message, "warning", { showReauth: true });
      } else {
        showToast(parsed.message, "error");
      }
    },
    [showToast],
  );

  return { handleError };
}
