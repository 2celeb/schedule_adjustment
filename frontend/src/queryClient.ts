import { QueryClient } from "@tanstack/react-query";

/**
 * TanStack Query クライアント設定
 *
 * - リトライ: 最大3回（エラーハンドリング設計に準拠）
 * - staleTime: 30秒（頻繁な再取得を抑制）
 * - gcTime: 5分（ガベージコレクション）
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 3,
      staleTime: 30 * 1000,
      gcTime: 5 * 60 * 1000,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 1,
    },
  },
});
