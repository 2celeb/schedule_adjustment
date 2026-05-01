/**
 * 参加可否セルコンポーネント
 *
 * 各セル（○/△/×/−）の表示と入力切り替えを担当する。
 * - 色分け表示: 緑=○、黄=△、赤=×、グレー=−
 * - ロケール設定による記号切り替え（availabilitySymbols.ts を使用）
 * - クリック/タップで status を切り替え
 *
 * 要件: 3.1, 3.2, 4.11, 4.12
 */
import { TableCell } from "@mui/material";
import type { AvailabilityStatus, SupportedLocale } from "@/utils/availabilitySymbols";
import {
  getAvailabilitySymbol,
  getAvailabilityColor,
} from "@/utils/availabilitySymbols";

interface AvailabilityCellProps {
  /** 参加可否ステータス（1=○, 0=△, -1=×, null=未入力） */
  status: AvailabilityStatus;
  /** ロケール */
  locale: SupportedLocale;
  /** クリック時のコールバック */
  onClick?: () => void;
  /** 無効状態（読み取り専用） */
  disabled?: boolean;
  /** 選択中ユーザーの列かどうか（ハイライト用） */
  isSelected?: boolean;
  /** テスト用 data-testid */
  "data-testid"?: string;
  /** ネイティブ title 属性（過去日付ロック時のツールチップ等） */
  title?: string;
}

export default function AvailabilityCell({
  status,
  locale,
  onClick,
  disabled = false,
  isSelected = false,
  "data-testid": testId,
  title,
}: AvailabilityCellProps) {
  const symbol = getAvailabilitySymbol(locale, status);
  const color = getAvailabilityColor(status);
  const isClickable = !disabled && !!onClick;

  return (
    <TableCell
      align="center"
      onClick={isClickable ? onClick : undefined}
      role={isClickable ? "button" : undefined}
      tabIndex={isClickable ? 0 : undefined}
      onKeyDown={
        isClickable
          ? (e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onClick?.();
              }
            }
          : undefined
      }
      aria-label={isClickable ? symbol : undefined}
      title={title}
      sx={{
        cursor: isClickable ? "pointer" : "default",
        color,
        fontWeight: "bold",
        fontSize: "0.875rem",
        px: 0.5,
        bgcolor: isSelected ? "action.selected" : undefined,
        "&:hover": isClickable
          ? { bgcolor: "action.hover" }
          : undefined,
        userSelect: "none",
      }}
      data-testid={testId}
    >
      {symbol}
    </TableCell>
  );
}
