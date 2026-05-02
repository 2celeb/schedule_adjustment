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
 * localStorage が利用可能かどうかを判定する
 * シークレットモードなどで利用不可の場合がある
 */
function isLocalStorageAvailable(): boolean {
  try {
    const testKey = "__storage_test__";
    localStorage.setItem(testKey, "1");
    localStorage.removeItem(testKey);
    return true;
  } catch {
    return false;
  }
}

/**
 * インメモリストレージ（localStorage 利用不可時のフォールバック）
 */
const inMemoryStorage: Record<string, string> = {};

/** localStorage が利用可能かどうかのキャッシュ */
let localStorageAvailable: boolean | null = null;

/**
 * ストレージから値を取得する
 * localStorage が利用不可の場合はインメモリストレージを使用する
 */
export function getStorageItem(key: string): string | null {
  if (localStorageAvailable === null) {
    localStorageAvailable = isLocalStorageAvailable();
  }

  if (localStorageAvailable) {
    return localStorage.getItem(key);
  }
  return inMemoryStorage[key] ?? null;
}

/**
 * ストレージに値を保存する
 * localStorage が利用不可の場合はインメモリストレージを使用する
 */
export function setStorageItem(key: string, value: string): void {
  if (localStorageAvailable === null) {
    localStorageAvailable = isLocalStorageAvailable();
  }

  if (localStorageAvailable) {
    localStorage.setItem(key, value);
  } else {
    inMemoryStorage[key] = value;
  }
}

/**
 * ストレージから値を削除する
 */
export function removeStorageItem(key: string): void {
  if (localStorageAvailable === null) {
    localStorageAvailable = isLocalStorageAvailable();
  }

  if (localStorageAvailable) {
    localStorage.removeItem(key);
  } else {
    delete inMemoryStorage[key];
  }
}

/**
 * localStorage が利用可能かどうかを返す
 */
export function isStorageAvailable(): boolean {
  if (localStorageAvailable === null) {
    localStorageAvailable = isLocalStorageAvailable();
  }
  return localStorageAvailable;
}

/**
 * リクエストインターセプター
 * ゆるい識別用の X-User-Id ヘッダーを自動付与
 */
apiClient.interceptors.request.use((config) => {
  const userId = getStorageItem("selectedUserId");
  if (userId) {
    config.headers["X-User-Id"] = userId;
  }
  return config;
});

/**
 * レスポンスインターセプター
 * エラーを再スローする（個別のハンドリングは useApiErrorHandler フックで行う）
 */
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    return Promise.reject(error);
  },
);

export default apiClient;
