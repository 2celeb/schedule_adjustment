/**
 * 閾値設定コンポーネント
 *
 * Threshold_N（参加不可人数の閾値）と対象（Core のみ / 全メンバー）の設定 UI を提供する。
 * Owner のみ変更可能。
 *
 * 要件: 4.8
 */
import { useState, useEffect, useCallback } from "react";
import {
  Box,
  Typography,
  TextField,
  RadioGroup,
  FormControlLabel,
  Radio,
  FormControl,
  FormLabel,
  Button,
  Alert,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import type { UpdateGroupParams } from "@/hooks/useGroupSettings";

interface ThresholdSettingsProps {
  /** 現在の閾値人数 */
  thresholdN: number | null;
  /** 現在の閾値対象 */
  thresholdTarget: "core" | "all";
  /** グループ更新関数 */
  onUpdate: (params: UpdateGroupParams) => void;
  /** 更新中かどうか */
  isUpdating: boolean;
}

export default function ThresholdSettings({
  thresholdN,
  thresholdTarget,
  onUpdate,
  isUpdating,
}: ThresholdSettingsProps) {
  const { t } = useTranslation();

  const [count, setCount] = useState<number | "">(thresholdN ?? "");
  const [target, setTarget] = useState<"core" | "all">(thresholdTarget);
  const [error, setError] = useState<string | null>(null);

  /* props が変更されたらフォームを更新 */
  useEffect(() => {
    setCount(thresholdN ?? "");
    setTarget(thresholdTarget);
  }, [thresholdN, thresholdTarget]);

  /* 保存ハンドラー */
  const handleSave = useCallback(() => {
    setError(null);

    const n = count === "" ? null : Number(count);

    if (n !== null && n < 1) {
      setError(
        t(
          "threshold.error.countMin",
          "閾値人数は1以上で指定してください。",
        ),
      );
      return;
    }

    onUpdate({
      threshold_n: n,
      threshold_target: target,
    });
  }, [count, target, onUpdate, t]);

  return (
    <Box sx={{ display: "flex", flexDirection: "column", gap: 2.5 }}>
      <Typography variant="h6" component="h3">
        {t("threshold.title")}
      </Typography>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* 閾値人数 */}
      <TextField
        label={t("threshold.count")}
        type="number"
        value={count}
        onChange={(e) =>
          setCount(e.target.value === "" ? "" : Number(e.target.value))
        }
        inputProps={{ min: 1 }}
        size="small"
        helperText={t(
          "threshold.countHelp",
          "この人数以上が参加不可の場合に警告表示されます。空欄で無効。",
        )}
      />

      {/* 閾値対象 */}
      <FormControl component="fieldset">
        <FormLabel component="legend">
          {t("threshold.target.label")}
        </FormLabel>
        <RadioGroup
          value={target}
          onChange={(e) => setTarget(e.target.value as "core" | "all")}
        >
          <FormControlLabel
            value="core"
            control={<Radio />}
            label={t("threshold.target.core")}
          />
          <FormControlLabel
            value="all"
            control={<Radio />}
            label={t("threshold.target.all")}
          />
        </RadioGroup>
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
