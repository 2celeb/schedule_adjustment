/**
 * 通知設定コンポーネント
 *
 * リマインド・通知に関する全設定項目の変更 UI を提供する。
 * - リマインド開始日（確定日のN日前）
 * - 当日通知時間（活動開始のN時間前）
 * - 通知チャンネル ID
 * - 当日通知メッセージ
 *
 * 要件: 6.8
 */
import { useState, useEffect, useCallback } from "react";
import {
  Box,
  Typography,
  TextField,
  Button,
  Alert,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import type { AutoScheduleRule, UpdateRuleParams } from "@/hooks/useGroupSettings";

interface NotificationSettingsProps {
  /** 現在のルール */
  rule: AutoScheduleRule | undefined;
  /** ルール更新関数 */
  onUpdate: (params: UpdateRuleParams) => void;
  /** 更新中かどうか */
  isUpdating: boolean;
}

export default function NotificationSettings({
  rule,
  onUpdate,
  isUpdating,
}: NotificationSettingsProps) {
  const { t } = useTranslation();

  const [remindDaysBefore, setRemindDaysBefore] = useState<number | "">(
    rule?.remind_days_before_confirm ?? 2,
  );
  const [notifyHoursBefore, setNotifyHoursBefore] = useState<number | "">(
    rule?.activity_notify_hours_before ?? 8,
  );
  const [notifyChannelId, setNotifyChannelId] = useState<string>(
    rule?.activity_notify_channel_id ?? "",
  );
  const [notifyMessage, setNotifyMessage] = useState<string>(
    rule?.activity_notify_message ?? "",
  );
  const [error, setError] = useState<string | null>(null);

  /* ルールが変更されたらフォームを更新 */
  useEffect(() => {
    if (rule) {
      setRemindDaysBefore(rule.remind_days_before_confirm ?? 2);
      setNotifyHoursBefore(rule.activity_notify_hours_before ?? 8);
      setNotifyChannelId(rule.activity_notify_channel_id ?? "");
      setNotifyMessage(rule.activity_notify_message ?? "");
    }
  }, [rule]);

  /* 保存ハンドラー */
  const handleSave = useCallback(() => {
    setError(null);

    const remind = remindDaysBefore === "" ? null : Number(remindDaysBefore);
    const notify = notifyHoursBefore === "" ? null : Number(notifyHoursBefore);

    if (remind !== null && remind < 0) {
      setError(t("notification.error.remindDaysNegative", "リマインド開始日は0以上で指定してください。"));
      return;
    }
    if (notify !== null && notify < 0) {
      setError(t("notification.error.notifyHoursNegative", "当日通知時間は0以上で指定してください。"));
      return;
    }

    onUpdate({
      remind_days_before_confirm: remind ?? 2,
      activity_notify_hours_before: notify ?? 8,
      activity_notify_channel_id: notifyChannelId || null,
      activity_notify_message: notifyMessage || null,
    });
  }, [
    remindDaysBefore,
    notifyHoursBefore,
    notifyChannelId,
    notifyMessage,
    onUpdate,
    t,
  ]);

  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2.5 }}>
      <Typography variant="h6" component="h3">
        {t("notification.title")}
      </Typography>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* リマインド開始日 */}
      <TextField
        label={t("notification.remindDaysBefore")}
        type="number"
        value={remindDaysBefore}
        onChange={(e) =>
          setRemindDaysBefore(e.target.value === "" ? "" : Number(e.target.value))
        }
        inputProps={{ min: 0 }}
        size="small"
        helperText={t(
          "notification.remindDaysHelp",
          "確定日の何日前からリマインドを開始するか",
        )}
      />

      {/* 当日通知時間 */}
      <TextField
        label={t("notification.activityNotifyHoursBefore")}
        type="number"
        value={notifyHoursBefore}
        onChange={(e) =>
          setNotifyHoursBefore(e.target.value === "" ? "" : Number(e.target.value))
        }
        inputProps={{ min: 0 }}
        size="small"
        helperText={t(
          "notification.notifyHoursHelp",
          "活動開始の何時間前に通知するか",
        )}
      />

      {/* 通知チャンネル ID */}
      <TextField
        label={t("notification.channel")}
        value={notifyChannelId}
        onChange={(e) => setNotifyChannelId(e.target.value)}
        size="small"
        placeholder="Discord チャンネル ID"
        helperText={t(
          "notification.channelHelp",
          "空欄の場合はデフォルトチャンネルに投稿されます",
        )}
      />

      {/* 当日通知メッセージ */}
      <TextField
        label={t("notification.activityNotifyMessage")}
        value={notifyMessage}
        onChange={(e) => setNotifyMessage(e.target.value)}
        size="small"
        multiline
        rows={3}
        placeholder={t(
          "notification.messagePlaceholder",
          "空欄の場合はデフォルトメッセージが使用されます",
        )}
        helperText={t(
          "notification.messageHelp",
          "活動日当日に投稿されるメッセージ",
        )}
      />

      {/* 保存ボタン */}
      <Button
        variant="contained"
        onClick={handleSave}
        disabled={isUpdating}
        sx={{ alignSelf: "flex-start" }}
      >
        {t("common.save")}
      </Button>
    </Box>
  );
}
