/**
 * メインスケジュールページ
 *
 * URL パラメータから share_token を取得し、グループ情報を読み込む。
 * メンバー選択バー + Availability_Board プレースホルダー + 広告配置プレースホルダーの
 * レイアウトを構成する。
 *
 * 要件: 1.1, 4.3
 */
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
import MemberSelector from "@/components/members/MemberSelector";

export default function SchedulePage() {
  const { t } = useTranslation();
  const { share_token } = useParams<{ share_token: string }>();
  const { group, members, isLoading, isError } = useGroup(share_token);
  const { selectedUserId, selectUser } = useCurrentUser();

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

      {/* Availability_Board プレースホルダー（タスク 9 で実装予定） */}
      <Paper
        variant="outlined"
        sx={{
          p: { xs: 2, sm: 3 },
          mb: 3,
          minHeight: 200,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
        data-testid="availability-board-placeholder"
      >
        <Typography color="text.secondary">
          {t("schedule.boardPlaceholder")}
        </Typography>
      </Paper>

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
