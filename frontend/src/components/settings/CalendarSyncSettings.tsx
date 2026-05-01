/**
 * カレンダー連携設定コンポーネント
 *
 * Google カレンダー連携の設定 UI を提供する。
 * - 連携パターン選択（連携なし / 予定枠のみ / 予定枠＋書き込み）
 * - 「今すぐ同期」ボタン
 * - Google 連携解除ボタン
 *
 * 要件: 7.1, 7.5, 7.6, 7.11
 */
import { useState, useCallback } from "react";
import {
  Box,
  Typography,
  Button,
  RadioGroup,
  FormControlLabel,
  Radio,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  CircularProgress,
  FormControl,
  FormLabel,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import { useCalendarSync } from "@/hooks/useCalendarSync";

/** 連携パターンの型 */
type SyncPattern = "none" | "freebusyOnly" | "freebusyAndWrite";

interface CalendarSyncSettingsProps {
  /** グループの共有トークン */
  shareToken: string;
  /** ユーザー ID */
  userId: number;
  /** Google カレンダースコープ（null の場合は未連携） */
  googleCalendarScope: string | null;
  /** Google 連携済みかどうか */
  isGoogleConnected: boolean;
  /** 連携解除後のコールバック */
  onDisconnected?: () => void;
}

/**
 * Google カレンダースコープから連携パターンを判定する
 */
function getSyncPattern(scope: string | null): SyncPattern {
  if (!scope) return "none";
  if (scope.includes("calendar.events") || scope === "calendar") {
    return "freebusyAndWrite";
  }
  if (scope.includes("freebusy")) {
    return "freebusyOnly";
  }
  return "none";
}

export default function CalendarSyncSettings({
  shareToken,
  userId,
  googleCalendarScope,
  isGoogleConnected,
  onDisconnected,
}: CalendarSyncSettingsProps) {
  const { t } = useTranslation();
  const {
    triggerSync,
    disconnectGoogle,
    isSyncing,
    isDisconnecting,
    syncSuccess,
    syncError,
    disconnectSuccess,
    disconnectError,
    resetSyncStatus,
    resetDisconnectStatus,
  } = useCalendarSync();

  const [disconnectDialogOpen, setDisconnectDialogOpen] = useState(false);

  /** 現在の連携パターン */
  const currentPattern = getSyncPattern(googleCalendarScope);

  /** 今すぐ同期ハンドラー */
  const handleSync = useCallback(() => {
    resetSyncStatus();
    triggerSync(shareToken);
  }, [shareToken, triggerSync, resetSyncStatus]);

  /** 連携解除確認ダイアログを開く */
  const handleDisconnectClick = useCallback(() => {
    setDisconnectDialogOpen(true);
  }, []);

  /** 連携解除を実行する */
  const handleDisconnectConfirm = useCallback(() => {
    setDisconnectDialogOpen(false);
    resetDisconnectStatus();
    disconnectGoogle(userId);
    onDisconnected?.();
  }, [userId, disconnectGoogle, resetDisconnectStatus, onDisconnected]);

  /** 連携解除ダイアログを閉じる */
  const handleDisconnectCancel = useCallback(() => {
    setDisconnectDialogOpen(false);
  }, []);

  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2.5 }}>
      <Typography variant="h6" component="h3">
        {t("calendar.sync")}
      </Typography>

      {/* 接続状態の表示 */}
      <Alert severity={isGoogleConnected ? "success" : "info"} icon={false}>
        {isGoogleConnected
          ? t("calendar.connected", "Google カレンダーに接続中")
          : t("calendar.notConnected", "Google カレンダーに接続されていません")}
      </Alert>

      {/* 同期成功メッセージ */}
      {syncSuccess && (
        <Alert severity="success" onClose={resetSyncStatus}>
          {t("calendar.syncSuccess", "同期をキューに追加しました")}
        </Alert>
      )}

      {/* 同期エラーメッセージ */}
      {syncError && (
        <Alert severity="error" onClose={resetSyncStatus}>
          {t("calendar.syncError", "同期に失敗しました")}
        </Alert>
      )}

      {/* 連携解除成功メッセージ */}
      {disconnectSuccess && (
        <Alert severity="success" onClose={resetDisconnectStatus}>
          {t("calendar.disconnectSuccess", "Google 連携を解除しました")}
        </Alert>
      )}

      {/* 連携解除エラーメッセージ */}
      {disconnectError && (
        <Alert severity="error" onClose={resetDisconnectStatus}>
          {t("calendar.disconnectError", "連携解除に失敗しました")}
        </Alert>
      )}

      {/* 連携パターン選択 */}
      <FormControl component="fieldset">
        <FormLabel component="legend">
          {t("calendar.patternLabel", "連携パターン")}
        </FormLabel>
        <RadioGroup value={currentPattern}>
          <FormControlLabel
            value="none"
            control={<Radio />}
            label={t("calendar.pattern.none")}
            disabled
          />
          <FormControlLabel
            value="freebusyOnly"
            control={<Radio />}
            label={t("calendar.pattern.freebusyOnly")}
            disabled
          />
          <FormControlLabel
            value="freebusyAndWrite"
            control={<Radio />}
            label={t("calendar.pattern.freebusyAndWrite")}
            disabled
          />
        </RadioGroup>
      </FormControl>

      {/* アクションボタン */}
      <Box sx={{ display: "flex", gap: 2, flexWrap: "wrap" }}>
        {/* 今すぐ同期ボタン */}
        <Button
          variant="contained"
          onClick={handleSync}
          disabled={!isGoogleConnected || isSyncing}
          startIcon={isSyncing ? <CircularProgress size={16} /> : undefined}
        >
          {t("calendar.syncNow")}
        </Button>

        {/* Google 連携解除ボタン */}
        <Button
          variant="outlined"
          color="error"
          onClick={handleDisconnectClick}
          disabled={!isGoogleConnected || isDisconnecting}
          startIcon={
            isDisconnecting ? <CircularProgress size={16} /> : undefined
          }
        >
          {t("calendar.disconnect")}
        </Button>
      </Box>

      {/* 連携解除確認ダイアログ */}
      <Dialog
        open={disconnectDialogOpen}
        onClose={handleDisconnectCancel}
        aria-labelledby="disconnect-dialog-title"
      >
        <DialogTitle id="disconnect-dialog-title">
          {t("calendar.disconnect")}
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {t(
              "calendar.disconnectConfirm",
              "Google 連携を解除しますか？",
            )}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDisconnectCancel}>
            {t("common.cancel")}
          </Button>
          <Button onClick={handleDisconnectConfirm} color="error" autoFocus>
            {t("common.confirm")}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
