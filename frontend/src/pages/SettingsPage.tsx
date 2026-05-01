/**
 * グループ設定ページ
 *
 * グループ基本設定 + 閾値設定 + 自動確定ルール + 通知設定 + カレンダー連携設定を
 * タブ形式で表示する。Owner のみアクセス可能（Cookie 認証）。
 *
 * 要件: 4.8, 5.2, 5.3, 5.4, 5.5, 6.8, 7.1
 */
import { useState } from "react";
import { useParams } from "react-router-dom";
import {
  Container,
  Typography,
  Box,
  Tabs,
  Tab,
  Paper,
  CircularProgress,
  Alert,
  Divider,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import { useQuery } from "@tanstack/react-query";
import apiClient from "@/api/client";
import { useAutoScheduleRule } from "@/hooks/useGroupSettings";
import AutoScheduleRuleForm from "@/components/events/AutoScheduleRuleForm";
import NotificationSettings from "@/components/settings/NotificationSettings";
import CalendarSyncSettings from "@/components/settings/CalendarSyncSettings";

/** グループ情報の型 */
interface GroupInfo {
  id: number;
  name: string;
  event_name: string;
  owner_id: number;
  share_token: string;
  timezone: string;
  default_start_time: string | null;
  default_end_time: string | null;
  threshold_n: number | null;
  threshold_target: string;
  ad_enabled: boolean;
  locale: string;
}

/** Owner ユーザー情報の型（カレンダー連携用） */
interface OwnerInfo {
  id: number;
  google_calendar_scope: string | null;
  google_account_id: string | null;
}

/** タブパネルコンポーネント */
function TabPanel({
  children,
  value,
  index,
}: {
  children: React.ReactNode;
  value: number;
  index: number;
}) {
  if (value !== index) return null;

  return (
    <Box sx={{ py: 3 }} role="tabpanel" aria-labelledby={`settings-tab-${index}`}>
      {children}
    </Box>
  );
}

export default function SettingsPage() {
  const { share_token } = useParams<{ share_token: string }>();
  const { t } = useTranslation();
  const [activeTab, setActiveTab] = useState(0);

  // グループ情報を取得
  const {
    data: groupData,
    isLoading: isGroupLoading,
    isError: isGroupError,
  } = useQuery<{ group: GroupInfo; owner?: OwnerInfo }>({
    queryKey: ["group", share_token],
    queryFn: async () => {
      const response = await apiClient.get(`/groups/${share_token}`);
      return response.data;
    },
    enabled: !!share_token,
  });

  const group = groupData?.group;
  const owner = groupData?.owner;

  // 自動確定ルール
  const {
    rule,
    isLoading: isRuleLoading,
    updateRule,
    isUpdating,
  } = useAutoScheduleRule(group?.id);

  // ローディング中
  if (isGroupLoading) {
    return (
      <Container maxWidth="md" sx={{ py: 4, textAlign: "center" }}>
        <CircularProgress />
        <Typography sx={{ mt: 2 }}>{t("common.loading")}</Typography>
      </Container>
    );
  }

  // エラー
  if (isGroupError || !group) {
    return (
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Alert severity="error">{t("schedule.noGroup")}</Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Typography variant="h4" component="h1" sx={{ mb: 1 }}>
        {t("group.settings")}
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        {group.name}
      </Typography>

      <Paper sx={{ px: 3, pb: 3 }}>
        <Tabs
          value={activeTab}
          onChange={(_, newValue) => setActiveTab(newValue)}
          variant="scrollable"
          scrollButtons="auto"
          sx={{ borderBottom: 1, borderColor: "divider" }}
        >
          <Tab label={t("autoSchedule.title")} id="settings-tab-0" />
          <Tab label={t("notification.title")} id="settings-tab-1" />
          <Tab label={t("calendar.sync")} id="settings-tab-2" />
        </Tabs>

        {/* 自動確定ルール */}
        <TabPanel value={activeTab} index={0}>
          {isRuleLoading ? (
            <Box sx={{ textAlign: "center", py: 4 }}>
              <CircularProgress size={24} />
            </Box>
          ) : (
            <AutoScheduleRuleForm
              rule={rule}
              onUpdate={updateRule}
              isUpdating={isUpdating}
            />
          )}
        </TabPanel>

        {/* 通知設定 */}
        <TabPanel value={activeTab} index={1}>
          {isRuleLoading ? (
            <Box sx={{ textAlign: "center", py: 4 }}>
              <CircularProgress size={24} />
            </Box>
          ) : (
            <NotificationSettings
              rule={rule}
              onUpdate={updateRule}
              isUpdating={isUpdating}
            />
          )}
        </TabPanel>

        {/* カレンダー連携設定 */}
        <TabPanel value={activeTab} index={2}>
          <CalendarSyncSettings
            shareToken={share_token!}
            userId={group.owner_id}
            googleCalendarScope={owner?.google_calendar_scope ?? null}
            isGoogleConnected={!!owner?.google_account_id}
            />
        </TabPanel>
      </Paper>
    </Container>
  );
}
