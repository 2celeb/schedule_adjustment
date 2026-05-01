/**
 * 活動日マーカーコンポーネント
 *
 * 確定済み活動日を他の日と視覚的に区別して表示する。
 * - 確定済み（confirmed=true）: 青色のマーカーを表示
 * - 未確定（confirmed=false）: 薄い色のマーカーを表示
 * - 時間変更あり（custom_time=true）: 赤の「!」マークで強調表示
 *   - ツールチップで実際の開始・終了時間を表示
 *
 * 要件: 5.10, 5.11
 */
import { Box, Tooltip } from "@mui/material";
import { useTranslation } from "react-i18next";
import type { EventDayEntry } from "@/types/availability";

interface EventDayMarkerProps {
  /** 活動日エントリ（undefined の場合は活動日ではない） */
  eventDay: EventDayEntry | undefined;
}

export default function EventDayMarker({ eventDay }: EventDayMarkerProps) {
  const { t } = useTranslation();

  /* 活動日でない場合は何も表示しない */
  if (!eventDay) {
    return null;
  }

  const isConfirmed = eventDay.confirmed;
  const hasCustomTime = eventDay.custom_time;

  /** マーカーのラベルテキスト */
  const label = isConfirmed
    ? t("eventDay.confirmed")
    : t("eventDay.unconfirmed");

  /** カスタム時間のツールチップテキスト */
  const customTimeTooltip = hasCustomTime
    ? `${t("eventDay.customTime")}: ${eventDay.start_time} - ${eventDay.end_time}`
    : "";

  return (
    <Box
      component="span"
      sx={{
        display: "inline-flex",
        alignItems: "center",
        gap: 0.25,
        ml: 0.5,
      }}
      data-testid="event-day-marker"
    >
      {/* 活動日マーカー（確定/未確定で色を変える） */}
      <Box
        component="span"
        sx={{
          display: "inline-block",
          width: 8,
          height: 8,
          borderRadius: "50%",
          bgcolor: isConfirmed ? "primary.main" : "grey.400",
          flexShrink: 0,
        }}
        aria-label={label}
        data-testid={
          isConfirmed
            ? "event-day-marker-confirmed"
            : "event-day-marker-unconfirmed"
        }
      />

      {/* カスタム時間の赤「!」マーク */}
      {hasCustomTime && (
        <Tooltip title={customTimeTooltip} arrow enterTouchDelay={0}>
          <Box
            component="span"
            sx={{
              color: "error.main",
              fontWeight: "bold",
              fontSize: "0.875rem",
              lineHeight: 1,
              cursor: "default",
            }}
            data-testid="event-day-custom-time-marker"
          >
            !
          </Box>
        </Tooltip>
      )}
    </Box>
  );
}
