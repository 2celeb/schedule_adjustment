import { Box, IconButton, Typography, ToggleButtonGroup, ToggleButton } from '@mui/material';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';

interface Props {
  year: number;
  month: number;
  viewMode: 'month' | 'week';
  onPrev: () => void;
  onNext: () => void;
  onViewModeChange: (mode: 'month' | 'week') => void;
}

export default function MonthNavigator({ year, month, viewMode, onPrev, onNext, onViewModeChange }: Props) {
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <IconButton onClick={onPrev} size="small">
          <ChevronLeftIcon />
        </IconButton>
        <Typography variant="h6" sx={{ fontWeight: 700, minWidth: 140, textAlign: 'center' }}>
          {year}年 {month}月
        </Typography>
        <IconButton onClick={onNext} size="small">
          <ChevronRightIcon />
        </IconButton>
      </Box>
      <ToggleButtonGroup
        value={viewMode}
        exclusive
        onChange={(_, v) => v && onViewModeChange(v)}
        size="small"
      >
        <ToggleButton value="month">月</ToggleButton>
        <ToggleButton value="week">週</ToggleButton>
      </ToggleButtonGroup>
    </Box>
  );
}
