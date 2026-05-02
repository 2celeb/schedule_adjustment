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
  Button,
} from "@mui/material";
import { useTranslation } from "react-i18next";
import { useQuery } from "@tanstack/react-query";
import apiClient from "@/api/client";
import { useAutoScheduleRule, useGroupUpdate } from "@/hooks/useGroupSettings";
import { useCurrentUser } from "@/hooks/useCurrentUser";
import GroupSettingsForm from "@/components/settings/GroupSettingsForm";
import ThresholdSettings from "@/components/settings/ThresholdSettings";
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
  threshold_target: "core" | "all";
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

  /* Owner 認証チェック（Cookie セッション） */
  const { selectedUserId, isAuthenticated, isLoading: isAuthLoading } = useCurrentUser();

  /* グループ情報を取得 */
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

  /* グループ設定更新 */
  const {
    updateGroup,
    isUpdating: isGroupUpdating,
  } = useGroupUpdate(group?.id, share_token);

  /* 自動確定ルール */
  const {
    rule,
    isLoading: isRuleLoading,
    updateRule,
    isUpdating: isRuleUpdating,
  } = useAutoScheduleRule(group?.id);

  /* ローディング中（認証確認 + グループ情報取得） */
  if (isAuthLoading || isGroupLoading) {
    return (
      <Container maxWidth="md" sx={{ py: 4, textAlign: "center" }}>
        <CircularProgress />
        <Typography sx={{ mt: 2 }}>{t("common.loading")}</Typography>
      </Container>
    );
  }

  /* グループが見つからない */
  if (isGroupError || !group) {
    return (
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Alert severity="error">{t("schedule.noGroup")}</Alert>
      </Container>
    );
  }

  /* Owner 認証チェック: Cookie セッションが無効、または選択ユーザーが Owner でない場合 */
  const isOwner = isAuthenticated && selectedUserId === group.owner_id;

  if (!isOwner) {
    return (
      <Container maxWidth="md" sx={{ py: 4 }}>
        <Alert severity="warning" sx={{ mb: 2 }}>
          {t("settings.ownerOnly", "この設定ページは Owner のみアクセスできます。")}
        </Alert>
        {!isAuthenticated && (
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            {t("settings.loginRequired", "設定を変更するには Google 認証でログインしてください。")}
          </Typography>
        )}
        <Button
          variant="outlined"
          href={`/${share_token}`}
        >
          {t("settings.backToSchedule", "スケジュールページに戻る")}
        </Button>
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
          <Tab
            label={t("groupSettings.title", "グループ基本設定")}
            id="settings-tab-0"
          />
          <Tab label={t("threshold.title")} id="settings-tab-1" />
          <Tab label={t("autoSchedule.title")} id="settings-tab-2" />
          <Tab label={t("notification.title")} id="settings-tab-3" />
          <Tab label={t("calendar.sync")} id="settings-tab-4" />
        </Tabs>

        {/* グループ基本設定 */}
        <TabPanel value={activeTab} index={0}>
          <GroupSettingsForm
            group={group}
            onUpdate={updateGroup}
            isUpdating={isGroupUpdating}
          />
        </TabPanel>

        {/* 閾値設定 */}
        <TabPanel value={activeTab} index={1}>
          <ThresholdSettings
            thresholdN={group.threshold_n}
            thresholdTarget={group.threshold_target}
            onUpdate={updateGroup}
            isUpdating={isGroupUpdating}
          />
        </TabPanel>

        {/* 自動確定ルール */}
        <TabPanel value={activeTab} index={2}>
          {isRuleLoading ? (
            <Box sx={{ textAlign: "center", py: 4 }}>
              <CircularProgress size={24} />
            </Box>
          ) : (
            <AutoScheduleRuleForm
              rule={rule}
              onUpdate={updateRule}
              isUpdating={isRuleUpdating}
            />
          )}
        </TabPanel>

        {/* 通知設定 */}
        <TabPanel value={activeTab} index={3}>
          {isRuleLoading ? (
            <Box sx={{ textAlign: "center", py: 4 }}>
              <CircularProgress size={24} />
            </Box>
          ) : (
            <NotificationSettings
              rule={rule}
              onUpdate={updateRule}
              isUpdating={isRuleUpdating}
            />
          )}
        </TabPanel>

        {/* カレンダー連携設定 */}
        <TabPanel value={activeTab} index={4}>
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
