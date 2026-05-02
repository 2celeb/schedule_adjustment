/**
 * トースト通知プロバイダー
 *
 * MUI の Snackbar + Alert を使用したグローバルトースト通知システム。
 * API エラー、成功メッセージ、警告をユーザーに表示する。
 *
 * 使用方法:
 *   const { showToast } = useToast();
 *   showToast("保存しました", "success");
 *   showToast("エラーが発生しました", "error");
 */
import {
  createContext,
  useContext,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import { Snackbar, Alert, type AlertColor, Button } from "@mui/material";
import { useTranslation } from "react-i18next";

/** トーストメッセージの型 */
interface ToastMessage {
  id: number;
  message: string;
  severity: AlertColor;
  /** 再ログインボタンを表示するかどうか */
  showReauth?: boolean;
}

/** トーストコンテキストの型 */
interface ToastContextValue {
  /** トーストを表示する */
  showToast: (
    message: string,
    severity?: AlertColor,
    options?: { showReauth?: boolean },
  ) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

let nextId = 0;

/** 自動非表示の時間（ミリ秒） */
const AUTO_HIDE_DURATION = 6000;

export function ToastProvider({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const showToast = useCallback(
    (
      message: string,
      severity: AlertColor = "error",
      options?: { showReauth?: boolean },
    ) => {
      const id = nextId++;
      setToasts((prev) => [
        ...prev,
        { id, message, severity, showReauth: options?.showReauth },
      ]);
    },
    [],
  );

  const handleClose = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const handleReauth = useCallback(() => {
    // OAuth 再認証ページへリダイレクト
    // 現在のページ URL を保持して戻れるようにする
    const currentPath = window.location.pathname + window.location.search;
    window.location.href = `/oauth/google?redirect=${encodeURIComponent(currentPath)}`;
  }, []);

  // 最新のトーストのみ表示（スタック表示は複雑になるため）
  const currentToast = toasts[0];

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      {currentToast && (
        <Snackbar
          open
          autoHideDuration={AUTO_HIDE_DURATION}
          onClose={() => handleClose(currentToast.id)}
          anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
        >
          <Alert
            onClose={() => handleClose(currentToast.id)}
            severity={currentToast.severity}
            variant="filled"
            sx={{ width: "100%" }}
            action={
              currentToast.showReauth ? (
                <Button
                  color="inherit"
                  size="small"
                  onClick={handleReauth}
                  sx={{ fontWeight: "bold" }}
                >
                  {t("auth.relogin")}
                </Button>
              ) : undefined
            }
          >
            {currentToast.message}
          </Alert>
        </Snackbar>
      )}
    </ToastContext.Provider>
  );
}

/**
 * トースト通知フック
 *
 * @example
 * const { showToast } = useToast();
 * showToast("保存しました", "success");
 */
export function useToast(): ToastContextValue {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error("useToast は ToastProvider 内で使用してください。");
  }
  return context;
}
