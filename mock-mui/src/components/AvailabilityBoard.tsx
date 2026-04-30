import { useState } from 'react';
import {
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  Paper, Tooltip, Typography, Box, Popover,
} from '@mui/material';
import ErrorOutlined from '@mui/icons-material/ErrorOutlined';
import Event from '@mui/icons-material/Event';
import CheckCircle from '@mui/icons-material/CheckCircle';
import Celebration from '@mui/icons-material/Celebration';
import type { Member, AvailabilityEntry, EventDay, DaySummary, AvailabilityStatus } from '../data/mockData';
import { getSymbol, getStatusColor, getStatusBgColor } from '../utils/symbols';

interface Props {
  year: number;
  month: number;
  members: Member[];
  availabilities: Record<string, Record<number, AvailabilityEntry>>;
  eventDays: Record<string, EventDay>;
  summary: Record<string, DaySummary>;
  selectedMemberId: number | null;
  thresholdN: number;
  thresholdTarget: 'core' | 'all';
  defaultStartTime: string;
  defaultEndTime: string;
  onStatusChange: (date: string, memberId: number, newStatus: AvailabilityStatus) => void;
}

const dayNames = ['日', '月', '火', '水', '木', '金', '土'];

function getDaysInMonth(year: number, month: number): Date[] {
  const days: Date[] = [];
  const lastDay = new Date(year, month, 0).getDate();
  for (let d = 1; d <= lastDay; d++) {
    days.push(new Date(year, month - 1, d));
  }
  return days;
}

function cycleStatus(current: AvailabilityStatus): AvailabilityStatus {
  if (current === null) return 1;
  if (current === 1) return 0;
  if (current === 0) return -1;
  return null;
}

// △/× のコメントを持つメンバー一覧を取得
function getCommentsForDate(
  dateStr: string,
  members: Member[],
  availabilities: Record<string, Record<number, AvailabilityEntry>>
): { name: string; status: AvailabilityStatus; comment: string }[] {
  const result: { name: string; status: AvailabilityStatus; comment: string }[] = [];
  for (const m of members) {
    const entry = availabilities[dateStr]?.[m.id];
    if (entry && (entry.status === 0 || entry.status === -1) && entry.comment) {
      result.push({ name: m.display_name, status: entry.status, comment: entry.comment });
    }
  }
  return result;
}

export default function AvailabilityBoard({
  year, month, members, availabilities, eventDays, summary,
  selectedMemberId, thresholdN, defaultStartTime, defaultEndTime, onStatusChange,
}: Props) {
  const days = getDaysInMonth(year, month);
  const coreMembers = members.filter(m => m.role === 'owner' || m.role === 'core');
  const subMembers = members.filter(m => m.role === 'sub');

  // 日付ホバーでコメント一覧を表示するための Popover 状態
  const [popoverAnchor, setPopoverAnchor] = useState<HTMLElement | null>(null);
  const [popoverDate, setPopoverDate] = useState<string>('');

  const handleDateHover = (event: React.MouseEvent<HTMLElement>, dateStr: string) => {
    const comments = getCommentsForDate(dateStr, members, availabilities);
    if (comments.length > 0) {
      setPopoverAnchor(event.currentTarget);
      setPopoverDate(dateStr);
    }
  };

  const handleDateLeave = () => {
    setPopoverAnchor(null);
    setPopoverDate('');
  };

  const popoverComments = popoverDate ? getCommentsForDate(popoverDate, members, availabilities) : [];

  return (
    <>
      <TableContainer component={Paper} sx={{ maxHeight: '70vh', overflow: 'auto' }}>
        <Table stickyHeader size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ minWidth: 170, fontWeight: 700, position: 'sticky', left: 0, zIndex: 3, bgcolor: 'background.paper' }}>
                日付
              </TableCell>
              <TableCell sx={{ minWidth: 36, fontWeight: 700, textAlign: 'center', color: '#22c55e' }}>○</TableCell>
              <TableCell sx={{ minWidth: 36, fontWeight: 700, textAlign: 'center', color: '#eab308' }}>△</TableCell>
              <TableCell sx={{ minWidth: 36, fontWeight: 700, textAlign: 'center', color: '#ef4444' }}>×</TableCell>
              <TableCell sx={{ minWidth: 36, fontWeight: 700, textAlign: 'center', color: '#9ca3af' }}>−</TableCell>
              {coreMembers.map(m => (
                <TableCell key={m.id} sx={{ minWidth: 52, textAlign: 'center', fontWeight: 600, fontSize: 12 }}>
                  <Tooltip title={`Discord: ${m.discord_screen_name}`} arrow>
                    <span>{m.display_name}</span>
                  </Tooltip>
                </TableCell>
              ))}
              <TableCell sx={{ borderLeft: '2px solid #e0e0e0', minWidth: 4 }} />
              {subMembers.map(m => (
                <TableCell key={m.id} sx={{ minWidth: 52, textAlign: 'center', fontWeight: 600, fontSize: 12 }}>
                  <Tooltip title={`Discord: ${m.discord_screen_name}`} arrow>
                    <span>{m.display_name}</span>
                  </Tooltip>
                </TableCell>
              ))}
            </TableRow>
          </TableHead>
          <TableBody>
            {days.map(date => {
              const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
              const dow = date.getDay();
              const event = eventDays[dateStr];
              const daySummary = summary[dateStr];
              const allOk = daySummary && daySummary.ok === members.length;
              const warning = daySummary && daySummary.ng >= thresholdN;
              const isConfirmedEvent = event?.confirmed;
              const allOkConfirmed = allOk && isConfirmedEvent;

              // 行の背景色を決定
              let rowBg = 'inherit';
              if (allOkConfirmed) rowBg = '#ecfdf5';       // 全員○ + 確定 = 濃い緑
              else if (allOk) rowBg = '#f0fdf4';           // 全員○ = 薄い緑
              else if (isConfirmedEvent) rowBg = '#eff6ff'; // 確定活動日 = 青
              else if (warning) rowBg = '#fef2f2';          // 警告 = 赤

              const hasComments = getCommentsForDate(dateStr, members, availabilities).length > 0;

              return (
                <TableRow key={dateStr} sx={{ bgcolor: rowBg }}>
                  {/* 日付セル */}
                  <TableCell
                    onMouseEnter={(e) => handleDateHover(e, dateStr)}
                    onMouseLeave={handleDateLeave}
                    sx={{
                      position: 'sticky', left: 0, zIndex: 1,
                      bgcolor: rowBg === 'inherit' ? 'background.paper' : rowBg,
                      fontWeight: 600, fontSize: 13,
                      color: dow === 0 ? '#ef4444' : dow === 6 ? '#3b82f6' : 'inherit',
                      cursor: hasComments ? 'help' : 'default',
                      borderLeft: allOkConfirmed ? '4px solid #22c55e' : isConfirmedEvent ? '4px solid #3b82f6' : 'none',
                    }}
                  >
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <Box component="span">{date.getDate()} ({dayNames[dow]})</Box>

                      {/* 時刻表示: 全日に表示、活動日は強調 */}
                      {(() => {
                        const displayStart = event ? event.start_time : defaultStartTime;
                        const displayEnd = event ? event.end_time : defaultEndTime;
                        const isCustom = event?.custom_time;

                        let timeColor = '#c0c0c0'; // 通常日: 薄いグレー
                        let timeFontWeight = 400;
                        if (isConfirmedEvent) {
                          timeColor = '#2563eb'; // 確定活動日: 青
                          timeFontWeight = 700;
                        } else if (event) {
                          timeColor = '#6b7280'; // 活動日候補: 濃いグレー
                          timeFontWeight = 600;
                        }

                        return (
                          <Typography component="span" sx={{
                            fontSize: 10, color: timeColor,
                            fontWeight: timeFontWeight, whiteSpace: 'nowrap',
                            textDecoration: isCustom ? 'underline' : 'none',
                            textDecorationColor: isCustom ? '#ef4444' : undefined,
                          }}>
                            {displayStart}〜{displayEnd}
                          </Typography>
                        );
                      })()}

                      {/* 全員○ + 確定 */}
                      {allOkConfirmed && (
                        <Tooltip title="全員参加可能・活動日確定 🎉" arrow>
                          <Celebration sx={{ fontSize: 16, color: '#22c55e' }} />
                        </Tooltip>
                      )}

                      {/* 全員○（未確定） */}
                      {allOk && !isConfirmedEvent && (
                        <Tooltip title="全員参加可能" arrow>
                          <CheckCircle sx={{ fontSize: 16, color: '#22c55e' }} />
                        </Tooltip>
                      )}

                      {/* 確定活動日（全員○ではない） */}
                      {isConfirmedEvent && !allOk && (
                        <Tooltip title={`活動日確定 ${event.start_time}〜${event.end_time}`} arrow>
                          <Event sx={{ fontSize: 16, color: '#2563eb' }} />
                        </Tooltip>
                      )}

                      {/* 未確定活動日 */}
                      {event && !event.confirmed && (
                        <Tooltip title={`活動日候補 ${event.start_time}〜${event.end_time}`} arrow>
                          <Event sx={{ fontSize: 16, color: '#9ca3af' }} />
                        </Tooltip>
                      )}

                      {/* カスタム時間 */}
                      {event?.custom_time && (
                        <Tooltip title={`活動時間変更: ${event.start_time}〜${event.end_time}`} arrow>
                          <ErrorOutlined sx={{ fontSize: 16, color: '#ef4444' }} />
                        </Tooltip>
                      )}

                      {/* コメントありインジケーター */}
                      {hasComments && (
                        <Box sx={{
                          width: 6, height: 6, borderRadius: '50%',
                          bgcolor: '#eab308', ml: 0.3,
                        }} />
                      )}
                    </Box>
                  </TableCell>

                  {/* 集計 */}
                  <TableCell sx={{ textAlign: 'center', color: '#22c55e', fontWeight: 600, fontSize: 13 }}>
                    {daySummary?.ok ?? 0}
                  </TableCell>
                  <TableCell sx={{ textAlign: 'center', color: '#eab308', fontWeight: 600, fontSize: 13 }}>
                    {daySummary?.maybe ?? 0}
                  </TableCell>
                  <TableCell sx={{ textAlign: 'center', color: '#ef4444', fontWeight: 600, fontSize: 13 }}>
                    {daySummary?.ng ?? 0}
                  </TableCell>
                  <TableCell sx={{ textAlign: 'center', color: '#9ca3af', fontWeight: 600, fontSize: 13 }}>
                    {daySummary?.none ?? 0}
                  </TableCell>

                  {/* Core メンバー */}
                  {coreMembers.map(m => {
                    const entry = availabilities[dateStr]?.[m.id];
                    return (
                      <StatusCell
                        key={m.id}
                        entry={entry}
                        memberName={m.display_name}
                        isEditable={selectedMemberId === m.id}
                        onClick={() => {
                          if (selectedMemberId === m.id) {
                            onStatusChange(dateStr, m.id, cycleStatus(entry?.status ?? null));
                          }
                        }}
                      />
                    );
                  })}

                  <TableCell sx={{ borderLeft: '2px solid #e0e0e0', p: 0 }} />

                  {/* Sub メンバー */}
                  {subMembers.map(m => {
                    const entry = availabilities[dateStr]?.[m.id];
                    return (
                      <StatusCell
                        key={m.id}
                        entry={entry}
                        memberName={m.display_name}
                        isEditable={selectedMemberId === m.id}
                        onClick={() => {
                          if (selectedMemberId === m.id) {
                            onStatusChange(dateStr, m.id, cycleStatus(entry?.status ?? null));
                          }
                        }}
                      />
                    );
                  })}
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </TableContainer>

      {/* 日付ホバー時のコメント一覧 Popover */}
      <Popover
        open={!!popoverAnchor}
        anchorEl={popoverAnchor}
        onClose={handleDateLeave}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
        transformOrigin={{ vertical: 'top', horizontal: 'left' }}
        disableRestoreFocus
        sx={{ pointerEvents: 'none' }}
      >
        <Box sx={{ p: 1.5, maxWidth: 280 }}>
          <Typography variant="caption" sx={{ fontWeight: 700, color: 'text.secondary', mb: 0.5, display: 'block' }}>
            💬 コメント一覧
          </Typography>
          {popoverComments.map((c, i) => (
            <Box key={i} sx={{ display: 'flex', gap: 1, alignItems: 'flex-start', py: 0.3 }}>
              <Typography sx={{
                fontSize: 12, fontWeight: 700, minWidth: 50,
                color: getStatusColor(c.status),
              }}>
                {getSymbol(c.status)} {c.name}
              </Typography>
              <Typography sx={{ fontSize: 12, color: 'text.secondary' }}>
                {c.comment}
              </Typography>
            </Box>
          ))}
        </Box>
      </Popover>
    </>
  );
}

function StatusCell({
  entry, memberName, isEditable, onClick,
}: {
  entry: AvailabilityEntry | undefined;
  memberName: string;
  isEditable: boolean;
  onClick: () => void;
}) {
  const status = entry?.status ?? null;
  const symbol = getSymbol(status);
  const color = getStatusColor(status);
  const bgColor = getStatusBgColor(status);

  const tooltipContent = entry?.comment
    ? `${memberName}: ${entry.comment}`
    : '';

  const cell = (
    <TableCell
      sx={{
        textAlign: 'center',
        cursor: isEditable ? 'pointer' : 'default',
        bgcolor: bgColor,
        transition: 'all 0.15s',
        '&:hover': isEditable ? { filter: 'brightness(0.92)' } : {},
        border: isEditable ? '2px solid #3b82f6' : undefined,
      }}
      onClick={onClick}
    >
      <Typography
        sx={{ fontWeight: 700, fontSize: 16, color, userSelect: 'none' }}
      >
        {symbol}
        {entry?.auto_synced && (
          <Typography component="span" sx={{ fontSize: 9, color: '#9ca3af', ml: 0.3 }}>
            自動
          </Typography>
        )}
      </Typography>
    </TableCell>
  );

  if (tooltipContent) {
    return (
      <Tooltip title={tooltipContent} arrow placement="top">
        {cell}
      </Tooltip>
    );
  }

  return cell;
}
