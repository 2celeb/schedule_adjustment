import axios from "axios";

/**
 * Axios クライアント設定
 *
 * - ベース URL: 環境変数 VITE_API_BASE_URL から取得（デフォルト: /api）
 * - withCredentials: true（HttpOnly Cookie の送信を有効化）
 * - タイムアウト: 15秒
 * - X-User-Id ヘッダー: ゆるい識別用（localStorage から取得）
 */
const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "/api",
  withCredentials: true,
  timeout: 15_000,
  headers: {
    "Content-Type": "application/json",
    Accept: "application/json",
  },
});

/**
 * リクエストインターセプター
 * ゆるい識別用の X-User-Id ヘッダーを自動付与
 */
apiClient.interceptors.request.use((config) => {
  const userId = localStorage.getItem("selectedUserId");
  if (userId) {
    config.headers["X-User-Id"] = userId;
  }
  return config;
});

/**
 * レスポンスインターセプター
 * 共通エラーハンドリング
 */
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    // 401 の場合はセッション期限切れとして処理
    // 各コンポーネントで個別にハンドリングするため、ここでは再スローのみ
    return Promise.reject(error);
  },
);

export default apiClient;
