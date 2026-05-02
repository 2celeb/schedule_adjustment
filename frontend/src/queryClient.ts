import { QueryClient } from "@tanstack/react-query";
import { AxiosError } from "axios";

/**
 * リトライ対象外の HTTP ステータスコード
 * クライアントエラー（4xx）はリトライしても結果が変わらないためスキップする
 */
const NON_RETRYABLE_STATUSES = new Set([400, 401, 403, 404, 409, 422]);

/**
 * リトライ判定関数
 * サーバーエラー（5xx）やネットワークエラーのみリトライする
 * クライアントエラー（4xx）はリトライしない
 */
function shouldRetry(failureCount: number, error: unknown): boolean {
  // 最大3回までリトライ
  if (failureCount >= 3) return false;

  // Axios エラーの場合、ステータスコードで判定
  if (isAxiosError(error) && error.response) {
    const status = error.response.status;
    // 429（レート制限）はリトライ対象
    if (status === 429) return true;
    // その他の 4xx はリトライしない
    if (NON_RETRYABLE_STATUSES.has(status)) return false;
  }

  // ネットワークエラー、5xx、その他はリトライする
  return true;
}

/**
 * リトライ遅延計算（指数バックオフ）
 * 1回目: 1秒、2回目: 2秒、3回目: 4秒
 */
function retryDelay(attemptIndex: number): number {
  return Math.min(1000 * 2 ** attemptIndex, 8000);
}

/**
 * Axios エラーかどうかを判定する型ガード
 */
function isAxiosError(error: unknown): error is AxiosError {
  return (
    typeof error === "object" &&
    error !== null &&
    "isAxiosError" in error &&
    (error as AxiosError).isAxiosError === true
  );
}

/**
 * TanStack Query クライアント設定
 *
 * - リトライ: 最大3回（4xx エラーはリトライしない）
 * - リトライ遅延: 指数バックオフ（1秒 → 2秒 → 4秒）
 * - staleTime: 30秒（頻繁な再取得を抑制）
 * - gcTime: 5分（ガベージコレクション）
 *
 * 要件: 設計ドキュメント セクション 7.5
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: shouldRetry,
      retryDelay,
      staleTime: 30 * 1000,
      gcTime: 5 * 60 * 1000,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: (failureCount, error) => {
        // ミューテーションは1回のみリトライ（サーバーエラーのみ）
        if (failureCount >= 1) return false;
        if (isAxiosError(error) && error.response) {
          const status = error.response.status;
          // 5xx のみリトライ
          return status >= 500;
        }
        return false;
      },
    },
  },
});
