/**
 * 活動時間の個別編集コンポーネント（Owner のみ）
 *
 * 活動日ごとの開始・終了時間を編集するためのインラインエディター。
 * デフォルト時間と異なる場合は custom_time フラグが true になる。
 *
 * 要件: 5.9
 */
import { useState, useCallback } from "react";
import {
  Box,
  TextField,
  IconButton,
  Tooltip,
} from "@mui/material";
import EditIcon from "@mui/icons-material/Edit";
import CheckIcon from "@mui/icons-material/Check";
import CloseIcon from "@mui/icons-material/Close";
import { useTranslation } from "react-i18next";
import type { EventDay, UpdateEventDayParams } from "@/hooks/useGroupSettings";

interface EventTimeEditorProps {
  /** 活動日データ */
  eventDay: EventDay;
  /** 更新関数 */
  onUpdate: (params: UpdateEventDayParams) => void;
  /** Owner かどうか */
  isOwner: boolean;
}

export default function EventTimeEditor({
  eventDay,
  onUpdate,
  isOwner,
}: EventTimeEditorProps) {
  const { t } = useTranslation();
  const [isEditing, setIsEditing] = useState(false);
  const [startTime, setStartTime] = useState(eventDay.start_time ?? "");
  const [endTime, setEndTime] = useState(eventDay.end_time ?? "");

  const handleEdit = useCallback(() => {
    setStartTime(eventDay.start_time ?? "");
    setEndTime(eventDay.end_time ?? "");
    setIsEditing(true);
  }, [eventDay]);

  const handleCancel = useCallback(() => {
    setIsEditing(false);
  }, []);

  const handleSave = useCallback(() => {
    onUpdate({
      id: eventDay.id,
      start_time: startTime || undefined,
      end_time: endTime || undefined,
    });
    setIsEditing(false);
  }, [eventDay.id, startTime, endTime, onUpdate]);

  if (!isOwner) {
    return (
      <Box
        component="span"
        sx={{ fontSize: "0.75rem", color: "text.secondary" }}
      >
        {eventDay.start_time} - {eventDay.end_time}
      </Box>
    );
  }

  if (isEditing) {
    return (
      <Box sx={{ display: "inline-flex", alignItems: "center", gap: 0.5 }}>
        <TextField
          type="time"
          value={startTime}
          onChange={(e) => setStartTime(e.target.value)}
          size="small"
          sx={{ width: 100 }}
          slotProps={{ inputLabel: { shrink: true } }}
        />
        <Box component="span" sx={{ mx: 0.25 }}>
          -
        </Box>
        <TextField
          type="time"
          value={endTime}
          onChange={(e) => setEndTime(e.target.value)}
          size="small"
          sx={{ width: 100 }}
          slotProps={{ inputLabel: { shrink: true } }}
        />
        <IconButton size="small" onClick={handleSave} color="primary">
          <CheckIcon fontSize="small" />
        </IconButton>
        <IconButton size="small" onClick={handleCancel}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </Box>
    );
  }

  return (
    <Box sx={{ display: "inline-flex", alignItems: "center", gap: 0.5 }}>
      <Box
        component="span"
        sx={{ fontSize: "0.75rem", color: "text.secondary" }}
      >
        {eventDay.start_time} - {eventDay.end_time}
      </Box>
      <Tooltip title={t("common.edit")}>
        <IconButton size="small" onClick={handleEdit}>
          <EditIcon sx={{ fontSize: "0.875rem" }} />
        </IconButton>
      </Tooltip>
    </Box>
  );
}
