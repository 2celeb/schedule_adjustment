/**
 * OAuth コールバック処理ページ
 *
 * Google OAuth 認証のコールバック結果を処理する。
 * - 成功時: セッション Cookie が自動設定される → メインページにリダイレクト
 * - エラー時: エラーメッセージを表示（409 = Google アカウント競合、その他 = 一般エラー）
 * - ローディング状態の表示
 *
 * 要件: 1.4, 1.5
 */
import { useEffect, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { Box, Typography, CircularProgress, Alert, Button } from "@mui/material";
import { useTranslation } from "react-i18next";

/** コールバック処理の状態 */
type CallbackStatus = "processing" | "success" | "error";

export default function OAuthCallbackPage() {
  const { t } = useTranslation();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  const [status, setStatus] = useState<CallbackStatus>("processing");
  const [errorMessage, setErrorMessage] = useState<string>("");

  useEffect(() => {
    const errorParam = searchParams.get("error");
    const errorCode = searchParams.get("error_code");

    if (errorParam) {
      /* エラーパラメータがある場合 */
      setStatus("error");
      if (errorCode === "409") {
        /* 409: Google アカウント競合 */
        setErrorMessage(t("auth.googleAccountConflict"));
      } else {
        /* その他のエラー */
        setErrorMessage(errorParam || t("auth.callbackError"));
      }
      return;
    }

    /* 成功: セッション Cookie はサーバー側で自動設定済み */
    setStatus("success");

    /* メインページにリダイレクト */
    const timer = setTimeout(() => {
      navigate("/", { replace: true });
    }, 1500);

    return () => clearTimeout(timer);
  }, [searchParams, navigate, t]);

  /** トップページに戻るハンドラー */
  const handleBackToTop = () => {
    navigate("/", { replace: true });
  };

  return (
    <Box
      sx={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        minHeight: "50vh",
        gap: 2,
        p: 3,
      }}
    >
      {status === "processing" && (
        <>
          <CircularProgress />
          <Typography>{t("auth.callbackProcessing")}</Typography>
        </>
      )}

      {status === "success" && (
        <>
          <CircularProgress />
          <Typography>{t("auth.callbackSuccess")}</Typography>
        </>
      )}

      {status === "error" && (
        <>
          <Alert severity="error" sx={{ maxWidth: 400, width: "100%" }}>
            {errorMessage}
          </Alert>
          <Button variant="outlined" onClick={handleBackToTop}>
            {t("auth.backToTop")}
          </Button>
        </>
      )}
    </Box>
  );
}
