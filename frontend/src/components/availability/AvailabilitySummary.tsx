/**
 * 日別集計表示コンポーネント
 *
 * 各日付の ○/△/×/− 人数をコンパクトに集計表示する。
 * 行の背景色条件（優先度順）:
 *   1. 閾値超過（赤）: ng >= threshold_n（threshold_n が設定されている場合）
 *   2. 全員参加可能（緑）: ng === 0 && maybe === 0 && none === 0
 *   3. 1名のみ参加不可（オレンジ）: ng === 1
 *   4. デフォルト（色なし）
 *
 * 要件: 4.4, 4.5, 4.6, 4.7
 */
import { Box, TableCell, Tooltip } from "@mui/material";
import { useTranslation } from "react-i18next";
import type { SummaryEntry } from "@/types/availability";

/** 行背景色の種別 */
export type RowHighlight =
  | "thresholdExceeded"
  | "allAvailable"
  | "oneUnavailable"
  | "default";

interface AvailabilitySummaryProps {
  /** 集計データ（undefined の場合はデータなし） */
  summary: SummaryEntry | undefined;
  /** 閾値人数（null の場合は未設定） */
  thresholdN: number | null;
  /** グループの総メンバー数 */
  totalMembers: number;
}

/**
 * 集計データから行ハイライト種別を判定する
 *
 * 優先度:
 *   1. 閾値超過（赤）
 *   2. 全員参加可能（緑）
 *   3. 1名のみ参加不可（オレンジ）
 *   4. デフォルト
 */
export function getRowHighlight(
  summary: SummaryEntry | undefined,
  thresholdN: number | null,
): RowHighlight {
  if (!summary) return "default";

  /* 1. 閾値超過チェック（最優先） */
  if (thresholdN !== null && summary.ng >= thresholdN) {
    return "thresholdExceeded";
  }

  /* 2. 全員参加可能チェック */
  if (summary.ng === 0 && summary.maybe === 0 && summary.none === 0) {
    return "allAvailable";
  }

  /* 3. 1名のみ参加不可チェック */
  if (summary.ng === 1) {
    return "oneUnavailable";
  }

  return "default";
}

/** 行ハイライト種別に対応する背景色 */
export const ROW_HIGHLIGHT_COLORS: Record<RowHighlight, string | undefined> = {
  thresholdExceeded: "#ffebee",
  allAvailable: "#e8f5e9",
  oneUnavailable: "#fff3e0",
  default: undefined,
};

/**
 * 行ハイライト種別に対応するツールチップテキストの i18n キーを返す
 * default の場合は null を返す
 */
export function getHighlightTooltipKey(
  highlight: RowHighlight,
): string | null {
  switch (highlight) {
    case "thresholdExceeded":
      return "threshold.warning";
    case "allAvailable":
      return "summary.allAvailable";
    case "oneUnavailable":
      return "summary.oneUnavailable";
    default:
      return null;
  }
}

export default function AvailabilitySummary({
  summary,
  thresholdN,
  totalMembers,
}: AvailabilitySummaryProps) {
  const { t } = useTranslation();

  /* データなしの場合 */
  if (!summary) {
    return (
      <TableCell
        align="center"
        sx={{
          fontSize: "0.75rem",
          px: 0.5,
          whiteSpace: "nowrap",
          color: "text.disabled",
        }}
        data-testid="summary-cell-empty"
      >
        {t("summary.noData")}
      </TableCell>
    );
  }

  const highlight = getRowHighlight(summary, thresholdN);
  const tooltipKey = getHighlightTooltipKey(highlight);
  const tooltipText = tooltipKey ? t(tooltipKey) : "";

  const cellContent = (
    <Box
      sx={{
        display: "flex",
        gap: 0.25,
        justifyContent: "center",
        flexWrap: "nowrap",
      }}
    >
      <Box component="span" sx={{ color: "#4caf50", fontWeight: "bold" }}>
        {t("summary.ok")}{summary.ok}
      </Box>
      <Box component="span" sx={{ color: "#ff9800", fontWeight: "bold" }}>
        {t("summary.maybe")}{summary.maybe}
      </Box>
      <Box component="span" sx={{ color: "#f44336", fontWeight: "bold" }}>
        {t("summary.ng")}{summary.ng}
      </Box>
      <Box component="span" sx={{ color: "#9e9e9e", fontWeight: "bold" }}>
        {t("summary.none")}{summary.none}
      </Box>
    </Box>
  );

  return (
    <TableCell
      align="center"
      sx={{
        fontSize: "0.75rem",
        px: 0.5,
        whiteSpace: "nowrap",
      }}
      data-testid="summary-cell"
    >
      {tooltipText ? (
        <Tooltip title={tooltipText} arrow>
          {cellContent}
        </Tooltip>
      ) : (
        cellContent
      )}
    </TableCell>
  );
}
