import { AxiosError } from "axios";
import i18n from "@/i18n";

/**
 * バックエンドの統一エラーレスポンス型
 * { error: { code, message, details? } }
 */
export interface ApiErrorDetail {
  field: string;
  message: string;
}

export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: ApiErrorDetail[];
  };
}

/**
 * パース済みの API エラー情報
 */
export interface ParsedApiError {
  /** バックエンドのエラーコード（例: VALIDATION_ERROR, NOT_FOUND） */
  code: string;
  /** ユーザー向けのエラーメッセージ */
  message: string;
  /** HTTP ステータスコード */
  status: number;
  /** フィールドレベルのエラー詳細 */
  details?: ApiErrorDetail[];
  /** 再ログインが必要かどうか */
  requiresReauth: boolean;
}

/**
 * エラーコードから i18n キーへのマッピング
 */
const ERROR_CODE_I18N_MAP: Record<string, string> = {
  UNAUTHORIZED: "error.sessionExpired",
  AUTH_LOCKED: "error.sessionExpired",
  FORBIDDEN: "error.forbidden",
  NOT_FOUND: "error.notFound",
  CONFLICT: "error.conflict",
  VALIDATION_ERROR: "error.validation",
  PARAMETER_MISSING: "error.validation",
  RATE_LIMIT_EXCEEDED: "error.rateLimited",
  INTERNAL_SERVER_ERROR: "error.serverError",
  EXTERNAL_SERVICE_ERROR: "error.externalService",
  EXTERNAL_SERVICE_TIMEOUT: "error.externalService",
  EXTERNAL_SERVICE_UNAVAILABLE: "error.externalService",
};

/**
 * HTTP ステータスコードから i18n キーへのフォールバックマッピング
 */
const STATUS_I18N_MAP: Record<number, string> = {
  400: "error.validation",
  401: "error.sessionExpired",
  403: "error.forbidden",
  404: "error.notFound",
  409: "error.conflict",
  422: "error.validation",
  429: "error.rateLimited",
  500: "error.serverError",
  502: "error.externalService",
};

/** 再認証が必要なエラーコード */
const REAUTH_CODES = new Set(["UNAUTHORIZED", "AUTH_LOCKED"]);

/** 再認証が必要な HTTP ステータス */
const REAUTH_STATUSES = new Set([401]);

/**
 * Axios エラーを ParsedApiError に変換する
 *
 * バックエンドの統一エラーレスポンス形式をパースし、
 * i18n 対応のユーザー向けメッセージを生成する。
 */
export function parseApiError(error: unknown): ParsedApiError {
  if (!isAxiosError(error)) {
    return {
      code: "UNKNOWN",
      message: i18n.t("error.unknown"),
      status: 0,
      requiresReauth: false,
    };
  }

  const axiosError = error as AxiosError<ApiErrorResponse>;

  // ネットワークエラー（レスポンスなし）
  if (!axiosError.response) {
    if (axiosError.code === "ECONNABORTED") {
      return {
        code: "TIMEOUT",
        message: i18n.t("error.timeout"),
        status: 0,
        requiresReauth: false,
      };
    }
    return {
      code: "NETWORK_ERROR",
      message: i18n.t("error.network"),
      status: 0,
      requiresReauth: false,
    };
  }

  const { status, data } = axiosError.response;
  const serverError = data?.error;

  // バックエンドの統一エラーレスポンスがある場合
  if (serverError?.code) {
    const i18nKey = ERROR_CODE_I18N_MAP[serverError.code];
    // バックエンドのメッセージを優先し、i18n はフォールバック
    const message = serverError.message || i18n.t(i18nKey || "error.unknown");

    return {
      code: serverError.code,
      message,
      status,
      details: serverError.details,
      requiresReauth: REAUTH_CODES.has(serverError.code),
    };
  }

  // バックエンドの統一形式でない場合（ステータスコードからフォールバック）
  const i18nKey = STATUS_I18N_MAP[status];
  return {
    code: `HTTP_${status}`,
    message: i18n.t(i18nKey || "error.unknown"),
    status,
    requiresReauth: REAUTH_STATUSES.has(status),
  };
}

/**
 * エラーからユーザー向けメッセージを取得する（簡易版）
 */
export function getErrorMessage(error: unknown): string {
  return parseApiError(error).message;
}

/**
 * エラーが再認証を必要とするかどうかを判定する
 */
export function requiresReauthentication(error: unknown): boolean {
  return parseApiError(error).requiresReauth;
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
