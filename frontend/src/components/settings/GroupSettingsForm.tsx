/**
 * グループ基本設定フォーム
 *
 * グループ名、イベント名、基本活動時間、タイムゾーン、ロケールの設定 UI を提供する。
 * Owner のみ変更可能。
 *
 * 要件: 2.2, 4.12, 5.9
 */
import { useState, useEffect, useCallback } from "react";
import {
  Box,
  Typography,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Button,
  Alert,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import type { UpdateGroupParams } from "@/hooks/useGroupSettings";

/** グループ情報の型（SettingsPage から渡される） */
interface GroupInfo {
  id: number;
  name: string;
  event_name: string;
  timezone: string;
  default_start_time: string | null;
  default_end_time: string | null;
  locale: string;
}

interface GroupSettingsFormProps {
  /** グループ情報 */
  group: GroupInfo;
  /** グループ更新関数 */
  onUpdate: (params: UpdateGroupParams) => void;
  /** 更新中かどうか */
  isUpdating: boolean;
}

/** サポートするタイムゾーン一覧 */
const TIMEZONES = [
  "Asia/Tokyo",
  "Asia/Seoul",
  "Asia/Shanghai",
  "Asia/Singapore",
  "Asia/Kolkata",
  "Europe/London",
  "Europe/Paris",
  "Europe/Berlin",
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "Pacific/Honolulu",
  "Pacific/Auckland",
] as const;

/** サポートするロケール一覧 */
const LOCALES = [
  { value: "ja", label: "日本語" },
  { value: "en", label: "English" },
] as const;

export default function GroupSettingsForm({
  group,
  onUpdate,
  isUpdating,
}: GroupSettingsFormProps) {
  const { t } = useTranslation();

  const [name, setName] = useState(group.name);
  const [eventName, setEventName] = useState(group.event_name);
  const [defaultStartTime, setDefaultStartTime] = useState(
    group.default_start_time ?? "",
  );
  const [defaultEndTime, setDefaultEndTime] = useState(
    group.default_end_time ?? "",
  );
  const [timezone, setTimezone] = useState(group.timezone);
  const [locale, setLocale] = useState(group.locale);
  const [error, setError] = useState<string | null>(null);

  /* グループ情報が変更されたらフォームを更新 */
  useEffect(() => {
    setName(group.name);
    setEventName(group.event_name);
    setDefaultStartTime(group.default_start_time ?? "");
    setDefaultEndTime(group.default_end_time ?? "");
    setTimezone(group.timezone);
    setLocale(group.locale);
  }, [group]);

  /* 保存ハンドラー */
  const handleSave = useCallback(() => {
    setError(null);

    if (!name.trim()) {
      setError(
        t(
          "groupSettings.error.nameRequired",
          "グループ名を入力してください。",
        ),
      );
      return;
    }

    if (!eventName.trim()) {
      setError(
        t(
          "groupSettings.error.eventNameRequired",
          "イベント名を入力してください。",
        ),
      );
      return;
    }

    onUpdate({
      name: name.trim(),
      event_name: eventName.trim(),
      default_start_time: defaultStartTime || null,
      default_end_time: defaultEndTime || null,
      timezone,
      locale,
    });
  }, [name, eventName, defaultStartTime, defaultEndTime, timezone, locale, onUpdate, t]);

  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2.5 }}>
      <Typography variant="h6" component="h3">
        {t("groupSettings.title", "グループ基本設定")}
      </Typography>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* グループ名 */}
      <TextField
        label={t("group.name")}
        value={name}
        onChange={(e) => setName(e.target.value)}
        size="small"
        required
      />

      {/* イベント名 */}
      <TextField
        label={t("group.eventName")}
        value={eventName}
        onChange={(e) => setEventName(e.target.value)}
        size="small"
        required
      />

      {/* 基本活動時間 */}
      <Box sx={{ display: "flex", gap: 2 }}>
        <TextField
          label={t("group.defaultStartTime")}
          type="time"
          value={defaultStartTime}
          onChange={(e) => setDefaultStartTime(e.target.value)}
          size="small"
          sx={{ flex: 1 }}
          slotProps={{ inputLabel: { shrink: true } }}
        />
        <TextField
          label={t("group.defaultEndTime")}
          type="time"
          value={defaultEndTime}
          onChange={(e) => setDefaultEndTime(e.target.value)}
          size="small"
          sx={{ flex: 1 }}
          slotProps={{ inputLabel: { shrink: true } }}
        />
      </Box>

      {/* タイムゾーン */}
      <FormControl size="small">
        <InputLabel>{t("group.timezone")}</InputLabel>
        <Select
          value={timezone}
          label={t("group.timezone")}
          onChange={(e) => setTimezone(e.target.value)}
        >
          {TIMEZONES.map((tz) => (
            <MenuItem key={tz} value={tz}>
              {tz}
            </MenuItem>
          ))}
        </Select>
      </FormControl>

      {/* ロケール */}
      <FormControl size="small">
        <InputLabel>{t("group.locale")}</InputLabel>
        <Select
          value={locale}
          label={t("group.locale")}
          onChange={(e) => setLocale(e.target.value)}
        >
          {LOCALES.map((loc) => (
            <MenuItem key={loc.value} value={loc.value}>
              {loc.label}
            </MenuItem>
          ))}
        </Select>
      </FormControl>

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
