/**
 * オフラインバナー
 *
 * ネットワーク接続が切断された場合に画面上部に警告バナーを表示する。
 * navigator.onLine と online/offline イベントを使用して接続状態を監視する。
 *
 * 要件: 設計ドキュメント セクション 7.5
 */
import { useState, useEffect } from "react";
import { Alert, Collapse } from "@mui/material";
import { useTranslation } from "react-i18next";

export function OfflineBanner() {
  const { t } = useTranslation();
  const [isOffline, setIsOffline] = useState(!navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setIsOffline(false);
    const handleOffline = () => setIsOffline(true);

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  return (
    <Collapse in={isOffline}>
      <Alert
        severity="warning"
        variant="filled"
        sx={{
          borderRadius: 0,
          justifyContent: "center",
        }}
      >
        {t("common.offline")}
      </Alert>
    </Collapse>
  );
}
