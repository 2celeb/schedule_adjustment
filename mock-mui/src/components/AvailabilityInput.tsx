import { useState } from 'react';
import {
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  Paper, Typography, Box, IconButton, TextField, Dialog, DialogTitle,
  DialogContent, DialogActions, Button, Chip,
} from '@mui/material';
import EditIcon from '@mui/icons-material/Edit';
import ChatBubbleOutlineOutlined from '@mui/icons-material/ChatBubbleOutlineOutlined';
import type { AvailabilityEntry, AvailabilityStatus } from '../data/mockData';
import type { CalendarSlot } from '../data/calendarData';
import { getSymbol, getStatusColor, getStatusBgColor } from '../utils/symbols';

interface Props {
  year: number;
  month: number;
  memberId: number;
  memberName: string;
  availabilities: Record<string, Record<number, AvailabilityEntry>>;
  calendarSlots: Record<string, CalendarSlot[]>;
  onStatusChange: (date: string, memberId: number, newStatus: AvailabilityStatus) => void;
  onCommentChange: (date: string, memberId: number, comment: string) => void;
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

const statusOptions: AvailabilityStatus[] = [1, 0, -1];

export default function AvailabilityInput({
  year, month, memberId, memberName, availabilities, calendarSlots,
  onStatusChange, onCommentChange,
}: Props) {
  const days = getDaysInMonth(year, month);
  const [commentDialog, setCommentDialog] = useState<{ date: string; comment: string } | null>(null);

  const handleStatusClick = (dateStr: string, status: AvailabilityStatus) => {
    const current = availabilities[dateStr]?.[memberId]?.status ?? null;
    const newStatus = current === status ? null : status;
    onStatusChange(dateStr, memberId, newStatus);

    if (newStatus === 0) {
      const existingComment = availabilities[dateStr]?.[memberId]?.comment ?? '';
      setCommentDialog({ date: dateStr, comment: existingComment ?? '' });
    }
  };

  const handleCommentSave = () => {
    if (commentDialog) {
      onCommentChange(commentDialog.date, memberId, commentDialog.comment);
      setCommentDialog(null);
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
          {memberName} の予定入力
        </Typography>
        <EditIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
      </Box>

      <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: '62vh', overflow: 'auto' }}>
        <Table stickyHeader size="small">
          <TableHead>
            <TableRow>
              <TableCell sx={{ fontWeight: 700, minWidth: 130 }}>日程</TableCell>
              {statusOptions.map(s => (
                <TableCell key={String(s)} sx={{ textAlign: 'center', fontWeight: 700, width: 52 }}>
                  <Typography sx={{ color: getStatusColor(s), fontWeight: 700, fontSize: 18 }}>
                    {getSymbol(s)}
                  </Typography>
                </TableCell>
              ))}
              <TableCell sx={{ width: 36, textAlign: 'center', p: 0 }} />
              <TableCell sx={{ fontWeight: 700, minWidth: 140, borderLeft: '2px solid #e0e0e0' }}>
                📅 Google 予定枠
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {days.map(date => {
              const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
              const dow = date.getDay();
              const entry = availabilities[dateStr]?.[memberId];
              const currentStatus = entry?.status ?? null;
              const hasComment = entry?.comment && entry.comment.length > 0;
              const slots = calendarSlots[dateStr];
              const hasSlots = slots && slots.length > 0;

              return (
                <TableRow key={dateStr} hover>
                  <TableCell sx={{
                    fontWeight: 600, fontSize: 13,
                    color: dow === 0 ? '#ef4444' : dow === 6 ? '#3b82f6' : 'inherit',
                  }}>
                    {String(month).padStart(2, '0')}/{String(date.getDate()).padStart(2, '0')}({dayNames[dow]})
                  </TableCell>

                  {statusOptions.map(s => {
                    const isSelected = currentStatus === s;
                    return (
                      <TableCell key={String(s)} sx={{ textAlign: 'center', p: 0.5 }}>
                        <Box
                          onClick={() => handleStatusClick(dateStr, s)}
                          sx={{
                            width: 38, height: 38, mx: 'auto',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            borderRadius: 1,
                            bgcolor: isSelected ? getStatusBgColor(s) : 'transparent',
                            border: isSelected ? `2px solid ${getStatusColor(s)}` : '2px solid transparent',
                            cursor: 'pointer',
                            transition: 'all 0.15s',
                            '&:hover': { bgcolor: getStatusBgColor(s), opacity: 0.8 },
                          }}
                        >
                          <Typography sx={{
                            fontWeight: 700, fontSize: 17,
                            color: isSelected ? getStatusColor(s) : '#d1d5db',
                          }}>
                            {getSymbol(s)}
                          </Typography>
                        </Box>
                      </TableCell>
                    );
                  })}

                  <TableCell sx={{ textAlign: 'center', p: 0 }}>
                    {(currentStatus === 0 || currentStatus === -1) && (
                      <IconButton
                        size="small"
                        onClick={() => {
                          const existingComment = entry?.comment ?? '';
                          setCommentDialog({ date: dateStr, comment: existingComment ?? '' });
                        }}
                        sx={{ color: hasComment ? '#3b82f6' : '#9ca3af' }}
                      >
                        <ChatBubbleOutlineOutlined sx={{ fontSize: 16 }} />
                      </IconButton>
                    )}
                  </TableCell>

                  <TableCell sx={{
                    borderLeft: '2px solid #e0e0e0',
                    bgcolor: hasSlots ? '#fef2f2' : 'transparent',
                    py: 0.5,
                  }}>
                    {hasSlots ? (
                      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                        {slots.map((slot, i) => (
                          <Chip
                            key={i}
                            label={`${slot.start}〜${slot.end}`}
                            size="small"
                            sx={{
                              fontSize: 11, height: 22,
                              bgcolor: '#fee2e2', color: '#991b1b', fontWeight: 600,
                            }}
                          />
                        ))}
                      </Box>
                    ) : (
                      <Typography sx={{ fontSize: 11, color: '#9ca3af' }}>−</Typography>
                    )}
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </TableContainer>

      {/* コメント入力ダイアログ */}
      <Dialog open={!!commentDialog} onClose={() => setCommentDialog(null)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ fontWeight: 700 }}>コメント入力</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 1, color: 'text.secondary' }}>
            {commentDialog?.date} のコメントを入力してください
          </Typography>
          <TextField
            autoFocus
            fullWidth
            multiline
            rows={3}
            value={commentDialog?.comment ?? ''}
            onChange={e => setCommentDialog(prev => prev ? { ...prev, comment: e.target.value } : null)}
            placeholder="例: 出張のため、体調不良 など"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCommentDialog(null)}>キャンセル</Button>
          <Button onClick={handleCommentSave} variant="contained">保存</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
