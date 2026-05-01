/**
 * コメントツールチップ / ポップオーバーコンポーネント
 *
 * ×/△ の日にカーソルを合わせるかタップした際にコメントをツールチップで表示する。
 * 選択中ユーザーが自分のセルをクリックした場合はコメント入力ポップオーバーを表示する。
 *
 * - 読み取り専用ツールチップ: 他メンバーの ×/△ セルにホバーでコメント表示（MUI Tooltip）
 * - コメント入力ポップオーバー: 選択中ユーザーの ×/△ セルクリック時に入力フォーム表示（MUI Popover）
 * - auto_synced が true の場合は「Google カレンダーから自動設定」テキストを表示
 *
 * 要件: 3.3, 3.4, 4.10
 */
import { useState, useRef } from "react";
import {
  Tooltip,
  Popover,
  Box,
  TextField,
  Button,
  Typography,
  TableCell,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import type { AvailabilityStatus, SupportedLocale } from "@/utils/availabilitySymbols";
import {
  getAvailabilitySymbol,
  getAvailabilityColor,
} from "@/utils/availabilitySymbols";

interface CommentTooltipProps {
  /** 参加可否ステータス */
  status: AvailabilityStatus;
  /** ロケール */
  locale: SupportedLocale;
  /** 既存のコメント（null の場合はコメントなし） */
  comment: string | null;
  /** Google カレンダーから自動設定されたかどうか */
  autoSynced: boolean;
  /** コメント入力ポップオーバーを表示するかどうか */
  showInput: boolean;
  /** コメント保存時のコールバック */
  onSaveComment: (comment: string) => void;
  /** ポップオーバーを閉じる時のコールバック */
  onClose: () => void;
  /** クリック時のコールバック */
  onClick?: () => void;
  /** 無効状態（読み取り専用） */
  disabled?: boolean;
  /** 選択中ユーザーの列かどうか */
  isSelected?: boolean;
  /** テスト用 data-testid */
  "data-testid"?: string;
}

export default function CommentTooltip({
  status,
  locale,
  comment,
  autoSynced,
  showInput,
  onSaveComment,
  onClose,
  onClick,
  disabled = false,
  isSelected = false,
  "data-testid": testId,
}: CommentTooltipProps) {
  const { t } = useTranslation();
  const [inputValue, setInputValue] = useState(comment ?? "");
  const cellRef = useRef<HTMLTableCellElement>(null);

  const symbol = getAvailabilitySymbol(locale, status);
  const color = getAvailabilityColor(status);
  const isClickable = !disabled && !!onClick;

  /** ポップオーバーの保存ボタンクリック */
  const handleSave = () => {
    onSaveComment(inputValue);
  };

  /** ポップオーバーの閉じるボタンクリック */
  const handleClose = () => {
    onClose();
  };

  /** ツールチップに表示するテキストを構築 */
  const buildTooltipContent = (): string => {
    const parts: string[] = [];
    if (comment) {
      parts.push(comment);
    }
    if (autoSynced) {
      parts.push(t("availability.autoSynced"));
    }
    return parts.join("\n");
  };

  const tooltipContent = buildTooltipContent();
  const hasTooltip = tooltipContent.length > 0 && !showInput;

  /** セルの中身 */
  const cellContent = (
    <TableCell
      ref={cellRef}
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

  return (
    <>
      {hasTooltip ? (
        <Tooltip
          title={tooltipContent}
          arrow
          enterTouchDelay={0}
        >
          {cellContent}
        </Tooltip>
      ) : (
        cellContent
      )}

      <Popover
        open={showInput}
        anchorEl={cellRef.current}
        onClose={handleClose}
        anchorOrigin={{
          vertical: "bottom",
          horizontal: "center",
        }}
        transformOrigin={{
          vertical: "top",
          horizontal: "center",
        }}
        data-testid="comment-popover"
      >
        <Box sx={{ p: 2, minWidth: 250 }} data-testid="comment-input-form">
          {autoSynced && (
            <Typography
              variant="caption"
              color="text.secondary"
              sx={{ display: "block", mb: 1 }}
              data-testid="auto-synced-indicator"
            >
              {t("availability.autoSynced")}
            </Typography>
          )}
          <TextField
            label={t("availability.comment.label")}
            placeholder={t("availability.comment.placeholder")}
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            size="small"
            fullWidth
            multiline
            minRows={2}
            maxRows={4}
            sx={{ mb: 1.5 }}
            data-testid="comment-input"
            inputProps={{ "data-testid": "comment-input-field" }}
          />
          <Box sx={{ display: "flex", gap: 1, justifyContent: "flex-end" }}>
            <Button
              variant="outlined"
              size="small"
              onClick={handleClose}
              data-testid="comment-close-button"
            >
              {t("common.close")}
            </Button>
            <Button
              variant="contained"
              size="small"
              onClick={handleSave}
              data-testid="comment-save-button"
            >
              {t("common.save")}
            </Button>
          </Box>
        </Box>
      </Popover>
    </>
  );
}
