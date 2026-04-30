import { useState, useMemo } from 'react';
import {
  Container, AppBar, Toolbar, Typography, Box, Paper, Chip, Tabs, Tab,
  ThemeProvider, createTheme, CssBaseline,
} from '@mui/material';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import MemberSelector from './components/MemberSelector';
import AvailabilityBoard from './components/AvailabilityBoard';
import AvailabilityInput from './components/AvailabilityInput';
import MonthNavigator from './components/MonthNavigator';
import {
  members, groupInfo, generateAvailabilities, generateEventDays, computeSummary,
} from './data/mockData';
import { generateCalendarSlots } from './data/calendarData';
import type { AvailabilityStatus } from './data/mockData';

const theme = createTheme({
  typography: {
    fontFamily: '"Noto Sans JP", "Roboto", "Helvetica", "Arial", sans-serif',
  },
  palette: {
    background: { default: '#f5f5f5' },
  },
});

export default function App() {
  const [selectedMemberId, setSelectedMemberId] = useState<number | null>(null);
  const [year, setYear] = useState(2025);
  const [month, setMonth] = useState(7);
  const [viewMode, setViewMode] = useState<'month' | 'week'>('month');
  const [tabIndex, setTabIndex] = useState(0); // 0=一覧, 1=入力
  const [availabilities, setAvailabilities] = useState(() => generateAvailabilities());
  const eventDays = useMemo(() => generateEventDays(), []);
  const summary = useMemo(() => computeSummary(availabilities), [availabilities]);

  // 選択中メンバーのカレンダー予定枠
  const calendarSlots = useMemo(() => {
    if (!selectedMemberId) return {};
    return generateCalendarSlots(selectedMemberId);
  }, [selectedMemberId]);

  const selectedMember = members.find(m => m.id === selectedMemberId);

  const handlePrev = () => {
    if (month === 1) { setYear(y => y - 1); setMonth(12); }
    else setMonth(m => m - 1);
  };
  const handleNext = () => {
    if (month === 12) { setYear(y => y + 1); setMonth(1); }
    else setMonth(m => m + 1);
  };

  const handleStatusChange = (date: string, memberId: number, newStatus: AvailabilityStatus) => {
    setAvailabilities(prev => ({
      ...prev,
      [date]: {
        ...prev[date],
        [memberId]: {
          ...prev[date]?.[memberId],
          status: newStatus,
          comment: prev[date]?.[memberId]?.comment ?? null,
          auto_synced: false,
        },
      },
    }));
  };

  const handleCommentChange = (date: string, memberId: number, comment: string) => {
    setAvailabilities(prev => ({
      ...prev,
      [date]: {
        ...prev[date],
        [memberId]: {
          ...prev[date]?.[memberId],
          comment: comment || null,
        },
      },
    }));
  };

  // メンバー選択時に入力タブに自動切り替え
  const handleMemberSelect = (id: number) => {
    setSelectedMemberId(id);
    setTabIndex(1);
  };

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <AppBar position="static" elevation={1} sx={{ bgcolor: '#1e293b' }}>
        <Toolbar>
          <CalendarMonthIcon sx={{ mr: 1 }} />
          <Typography variant="h6" sx={{ flexGrow: 1, fontWeight: 700 }}>
            {groupInfo.name} - スケジュール調整
          </Typography>
          <Chip label="MUI版モック" size="small" color="warning" />
        </Toolbar>
      </AppBar>

      <Container maxWidth="xl" sx={{ mt: 3, mb: 4 }}>
        {/* メンバー選択 */}
        <Paper sx={{ p: 2, mb: 2 }}>
          <MemberSelector
            members={members}
            selectedId={selectedMemberId}
            onSelect={handleMemberSelect}
          />
        </Paper>

        {/* タブ切り替え */}
        <Paper sx={{ mb: 2 }}>
          <Tabs
            value={tabIndex}
            onChange={(_, v) => setTabIndex(v)}
            sx={{ borderBottom: 1, borderColor: 'divider' }}
          >
            <Tab label="📊 スケジュール一覧" />
            <Tab
              label={selectedMember ? `✏️ ${selectedMember.display_name} の予定入力` : '✏️ 予定入力'}
              disabled={!selectedMemberId}
            />
          </Tabs>
        </Paper>

        {/* 月ナビゲーション（共通） */}
        <Paper sx={{ p: 2 }}>
          <MonthNavigator
            year={year}
            month={month}
            viewMode={viewMode}
            onPrev={handlePrev}
            onNext={handleNext}
            onViewModeChange={setViewMode}
          />

          {/* タブ内容 */}
          {tabIndex === 0 && (
            <>
              <AvailabilityBoard
                year={year}
                month={month}
                members={members}
                availabilities={availabilities}
                eventDays={eventDays}
                summary={summary}
                selectedMemberId={selectedMemberId}
                thresholdN={groupInfo.threshold_n}
                thresholdTarget={groupInfo.threshold_target}
                defaultStartTime={groupInfo.default_start_time}
                defaultEndTime={groupInfo.default_end_time}
                onStatusChange={handleStatusChange}
              />

              {/* 凡例 */}
              <Box sx={{ mt: 2, display: 'flex', gap: 2, flexWrap: 'wrap', fontSize: 12 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Box sx={{ width: 16, height: 16, bgcolor: '#dcfce7', border: '1px solid #ccc', borderRadius: 0.5 }} />
                  <Typography variant="caption">○ 参加可能</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Box sx={{ width: 16, height: 16, bgcolor: '#fef9c3', border: '1px solid #ccc', borderRadius: 0.5 }} />
                  <Typography variant="caption">△ 未定</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Box sx={{ width: 16, height: 16, bgcolor: '#fee2e2', border: '1px solid #ccc', borderRadius: 0.5 }} />
                  <Typography variant="caption">× 参加不可</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Box sx={{ width: 16, height: 16, bgcolor: '#f3f4f6', border: '1px solid #ccc', borderRadius: 0.5 }} />
                  <Typography variant="caption">− 未入力</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Box sx={{ width: 16, height: 16, bgcolor: '#eff6ff', border: '1px solid #ccc', borderRadius: 0.5 }} />
                  <Typography variant="caption">活動日（確定）</Typography>
                </Box>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <Box sx={{ width: 16, height: 16, bgcolor: '#fef2f2', border: '1px solid #ccc', borderRadius: 0.5 }} />
                  <Typography variant="caption">警告（×が{groupInfo.threshold_n}人以上）</Typography>
                </Box>
              </Box>
            </>
          )}

          {tabIndex === 1 && selectedMemberId && selectedMember && (
            <AvailabilityInput
              year={year}
              month={month}
              memberId={selectedMemberId}
              memberName={selectedMember.display_name}
              availabilities={availabilities}
              calendarSlots={calendarSlots}
              onStatusChange={handleStatusChange}
              onCommentChange={handleCommentChange}
            />
          )}

          {tabIndex === 1 && !selectedMemberId && (
            <Box sx={{ py: 8, textAlign: 'center' }}>
              <Typography variant="body1" color="text.secondary">
                メンバーを選択してください
              </Typography>
            </Box>
          )}
        </Paper>
      </Container>
    </ThemeProvider>
  );
}
