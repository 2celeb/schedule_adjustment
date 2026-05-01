/**
 * メインスケジュールページ
 *
 * URL パラメータから share_token を取得し、グループ情報を読み込む。
 * メンバー選択バー + Availability_Board + 広告配置プレースホルダーの
 * レイアウトを構成する。
 *
 * 要件: 1.1, 4.3, 3.1, 3.2
 */
import { useState, useCallback } from "react";
import { useParams } from "react-router-dom";
import {
  Container,
  Box,
  Typography,
  CircularProgress,
  Alert,
  Paper,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import { useGroup } from "@/hooks/useGroup";
import { useCurrentUser } from "@/hooks/useCurrentUser";
import {
  useAvailabilities,
  cycleStatus,
} from "@/hooks/useAvailabilities";
import MemberSelector from "@/components/members/MemberSelector";
import AvailabilityBoard, {
  formatMonthKey,
} from "@/components/availability/AvailabilityBoard";
import type { SupportedLocale, AvailabilityStatus } from "@/utils/availabilitySymbols";

export default function SchedulePage() {
  const { t } = useTranslation();
  const { share_token } = useParams<{ share_token: string }>();
  const { group, members, isLoading, isError } = useGroup(share_token);
  const { selectedUserId, selectUser } = useCurrentUser();

  /* 現在表示中の月（YYYY-MM 形式） */
  const [currentMonth, setCurrentMonth] = useState<string>(
    () => formatMonthKey(new Date()),
  );

  /* 参加可否データの取得・更新 */
  const {
    availabilities,
    eventDays,
    summary,
    updateAvailability,
  } = useAvailabilities(share_token, currentMonth);

  /* 月変更ハンドラー */
  const handleMonthChange = useCallback((month: string) => {
    setCurrentMonth(month);
  }, []);

  /* ステータス変更ハンドラー */
  const handleStatusChange = useCallback(
    (date: string, memberId: number, newStatus: AvailabilityStatus) => {
      updateAvailability({
        userId: memberId,
        date,
        status: newStatus,
        comment: null,
      });
    },
    [updateAvailability],
  );

  /* コメント保存ハンドラー */
  const handleCommentSave = useCallback(
    (date: string, memberId: number, comment: string) => {
      /* 現在の status を取得してコメント付きで再保存 */
      const entry = availabilities[date]?.[String(memberId)];
      const currentStatus = entry?.status ?? null;
      if (currentStatus !== null) {
        updateAvailability({
          userId: memberId,
          date,
          status: currentStatus,
          comment: comment || null,
        });
      }
    },
    [updateAvailability, availabilities],
  );

  /* ローディング状態 */
  if (isLoading) {
    return (
      <Box
        sx={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          minHeight: "50vh",
          gap: 2,
        }}
      >
        <CircularProgress />
        <Typography>{t("common.loading")}</Typography>
      </Box>
    );
  }

  /* エラー状態 */
  if (isError || !group) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Alert severity="error">{t("schedule.noGroup")}</Alert>
      </Container>
    );
  }

  return (
    <Container
      maxWidth="lg"
      sx={{
        py: { xs: 2, sm: 4 },
        px: { xs: 1, sm: 2, md: 3 },
      }}
    >
      {/* ヘッダー: グループ名 + イベント名 */}
      <Box sx={{ mb: 3 }}>
        <Typography
          variant="h5"
          component="h1"
          sx={{ fontWeight: "bold", mb: 0.5 }}
        >
          {group.name}
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          {group.event_name}
        </Typography>
      </Box>

      {/* メンバー選択バー */}
      <MemberSelector
        members={members}
        selectedUserId={selectedUserId}
        onSelectUser={selectUser}
      />

      {/* Availability_Board */}
      <AvailabilityBoard
        group={group}
        members={members}
        availabilities={availabilities}
        eventDays={eventDays}
        summary={summary}
        selectedUserId={selectedUserId}
        locale={(group.locale as SupportedLocale) || "ja"}
        onStatusChange={handleStatusChange}
        onCommentSave={handleCommentSave}
        onMonthChange={handleMonthChange}
      />

      {/* 広告配置プレースホルダー（タスク 18 で実装予定） */}
      {group.ad_enabled && (
        <Paper
          variant="outlined"
          sx={{
            p: 2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            bgcolor: "grey.50",
          }}
          data-testid="ad-placeholder"
        >
          <Typography variant="body2" color="text.secondary">
            {t("schedule.adPlaceholder")}
          </Typography>
        </Paper>
      )}
    </Container>
  );
}
