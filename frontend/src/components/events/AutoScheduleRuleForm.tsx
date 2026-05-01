/**
 * 自動確定ルール設定フォーム
 *
 * Owner が自動確定ルールを設定するためのフォーム。
 * - 最大/最低活動日数
 * - 優先度を下げる曜日
 * - 除外曜日
 * - 週の始まり
 * - 確定日（週の始まりのN日前）
 * - 確定時刻
 *
 * 要件: 5.2, 5.3
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
  Chip,
  Button,
  Alert,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import type { AutoScheduleRule, UpdateRuleParams } from "@/hooks/useGroupSettings";

interface AutoScheduleRuleFormProps {
  /** 現在のルール */
  rule: AutoScheduleRule | undefined;
  /** ルール更新関数 */
  onUpdate: (params: UpdateRuleParams) => void;
  /** 更新中かどうか */
  isUpdating: boolean;
}

/** 曜日の選択肢（0=日曜〜6=土曜） */
const WEEKDAYS = [0, 1, 2, 3, 4, 5, 6] as const;

export default function AutoScheduleRuleForm({
  rule,
  onUpdate,
  isUpdating,
}: AutoScheduleRuleFormProps) {
  const { t } = useTranslation();

  const [maxDays, setMaxDays] = useState<number | "">(rule?.max_days_per_week ?? "");
  const [minDays, setMinDays] = useState<number | "">(rule?.min_days_per_week ?? "");
  const [deprioritizedDays, setDeprioritizedDays] = useState<number[]>(
    rule?.deprioritized_days ?? [],
  );
  const [excludedDays, setExcludedDays] = useState<number[]>(
    rule?.excluded_days ?? [],
  );
  const [weekStartDay, setWeekStartDay] = useState<number>(
    rule?.week_start_day ?? 1,
  );
  const [confirmDaysBefore, setConfirmDaysBefore] = useState<number | "">(
    rule?.confirm_days_before ?? 3,
  );
  const [confirmTime, setConfirmTime] = useState<string>(
    rule?.confirm_time ?? "21:00",
  );
  const [error, setError] = useState<string | null>(null);

  /* ルールが変更されたらフォームを更新 */
  useEffect(() => {
    if (rule) {
      setMaxDays(rule.max_days_per_week ?? "");
      setMinDays(rule.min_days_per_week ?? "");
      setDeprioritizedDays(rule.deprioritized_days);
      setExcludedDays(rule.excluded_days);
      setWeekStartDay(rule.week_start_day);
      setConfirmDaysBefore(rule.confirm_days_before);
      setConfirmTime(rule.confirm_time ?? "21:00");
    }
  }, [rule]);

  /* 曜日チップのトグル */
  const toggleDay = useCallback(
    (day: number, list: number[], setter: (days: number[]) => void) => {
      if (list.includes(day)) {
        setter(list.filter((d) => d !== day));
      } else {
        setter([...list, day].sort());
      }
    },
    [],
  );

  /* 保存ハンドラー */
  const handleSave = useCallback(() => {
    setError(null);

    /* バリデーション */
    const max = maxDays === "" ? null : Number(maxDays);
    const min = minDays === "" ? null : Number(minDays);
    const confirm = confirmDaysBefore === "" ? null : Number(confirmDaysBefore);

    if (max !== null && (max < 1 || max > 7)) {
      setError("最大活動日数は1〜7の範囲で指定してください。");
      return;
    }
    if (min !== null && min < 0) {
      setError("最低活動日数は0以上で指定してください。");
      return;
    }
    if (max !== null && min !== null && min > max) {
      setError("最低活動日数は最大活動日数以下にしてください。");
      return;
    }
    if (confirm !== null && confirm < 1) {
      setError("確定日は1以上で指定してください。");
      return;
    }

    onUpdate({
      max_days_per_week: max,
      min_days_per_week: min,
      deprioritized_days: deprioritizedDays,
      excluded_days: excludedDays,
      week_start_day: weekStartDay,
      confirm_days_before: confirm ?? 3,
      confirm_time: confirmTime,
    });
  }, [
    maxDays,
    minDays,
    deprioritizedDays,
    excludedDays,
    weekStartDay,
    confirmDaysBefore,
    confirmTime,
    onUpdate,
  ]);

  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2.5 }}>
      <Typography variant="h6" component="h3">
        {t("autoSchedule.title")}
      </Typography>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* 最大/最低活動日数 */}
      <Box sx={{ display: "flex", gap: 2 }}>
        <TextField
          label={t("autoSchedule.maxDaysPerWeek")}
          type="number"
          value={maxDays}
          onChange={(e) =>
            setMaxDays(e.target.value === "" ? "" : Number(e.target.value))
          }
          inputProps={{ min: 1, max: 7 }}
          size="small"
          sx={{ flex: 1 }}
        />
        <TextField
          label={t("autoSchedule.minDaysPerWeek")}
          type="number"
          value={minDays}
          onChange={(e) =>
            setMinDays(e.target.value === "" ? "" : Number(e.target.value))
          }
          inputProps={{ min: 0, max: 7 }}
          size="small"
          sx={{ flex: 1 }}
        />
      </Box>

      {/* 優先度を下げる曜日 */}
      <Box>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          {t("autoSchedule.deprioritizedDays")}
        </Typography>
        <Box sx={{ display: "flex", gap: 0.5, flexWrap: "wrap" }}>
          {WEEKDAYS.map((day) => (
            <Chip
              key={`depri-${day}`}
              label={t(`weekday.${day}`)}
              onClick={() =>
                toggleDay(day, deprioritizedDays, setDeprioritizedDays)
              }
              color={deprioritizedDays.includes(day) ? "warning" : "default"}
              variant={deprioritizedDays.includes(day) ? "filled" : "outlined"}
              size="small"
            />
          ))}
        </Box>
      </Box>

      {/* 除外曜日 */}
      <Box>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          {t("autoSchedule.excludedDays")}
        </Typography>
        <Box sx={{ display: "flex", gap: 0.5, flexWrap: "wrap" }}>
          {WEEKDAYS.map((day) => (
            <Chip
              key={`excl-${day}`}
              label={t(`weekday.${day}`)}
              onClick={() => toggleDay(day, excludedDays, setExcludedDays)}
              color={excludedDays.includes(day) ? "error" : "default"}
              variant={excludedDays.includes(day) ? "filled" : "outlined"}
              size="small"
            />
          ))}
        </Box>
      </Box>

      {/* 週の始まり */}
      <FormControl size="small">
        <InputLabel>{t("autoSchedule.weekStartDay")}</InputLabel>
        <Select
          value={weekStartDay}
          label={t("autoSchedule.weekStartDay")}
          onChange={(e) => setWeekStartDay(Number(e.target.value))}
        >
          {WEEKDAYS.map((day) => (
            <MenuItem key={day} value={day}>
              {t(`weekday.${day}`)}
            </MenuItem>
          ))}
        </Select>
      </FormControl>

      {/* 確定日・確定時刻 */}
      <Box sx={{ display: "flex", gap: 2 }}>
        <TextField
          label={t("autoSchedule.confirmDaysBefore")}
          type="number"
          value={confirmDaysBefore}
          onChange={(e) =>
            setConfirmDaysBefore(
              e.target.value === "" ? "" : Number(e.target.value),
            )
          }
          inputProps={{ min: 1 }}
          size="small"
          sx={{ flex: 1 }}
        />
        <TextField
          label={t("autoSchedule.confirmTime")}
          type="time"
          value={confirmTime}
          onChange={(e) => setConfirmTime(e.target.value)}
          size="small"
          sx={{ flex: 1 }}
          slotProps={{ inputLabel: { shrink: true } }}
        />
      </Box>

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
