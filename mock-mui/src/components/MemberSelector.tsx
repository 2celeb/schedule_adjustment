import { Chip, Tooltip, Box, Typography } from '@mui/material';
import LockIcon from '@mui/icons-material/Lock';
import type { Member } from '../data/mockData';

interface Props {
  members: Member[];
  selectedId: number | null;
  onSelect: (id: number) => void;
}

function getRoleColor(role: Member['role']): 'primary' | 'success' | 'default' {
  switch (role) {
    case 'owner': return 'primary';
    case 'core': return 'success';
    default: return 'default';
  }
}

function getRoleLabel(role: Member['role']): string {
  switch (role) {
    case 'owner': return 'Owner';
    case 'core': return 'Core';
    default: return 'Sub';
  }
}

export default function MemberSelector({ members, selectedId, onSelect }: Props) {
  return (
    <Box sx={{ mb: 2 }}>
      <Typography variant="subtitle2" sx={{ mb: 1, color: 'text.secondary' }}>
        メンバーを選択してください
      </Typography>
      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
        {members.map((m) => (
          <Tooltip
            key={m.id}
            title={`Discord: ${m.discord_screen_name} (${getRoleLabel(m.role)})`}
            arrow
          >
            <Chip
              label={
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  {m.display_name}
                  {m.auth_locked && <LockIcon sx={{ fontSize: 14 }} />}
                </Box>
              }
              color={getRoleColor(m.role)}
              variant={selectedId === m.id ? 'filled' : 'outlined'}
              onClick={() => onSelect(m.id)}
              sx={{
                fontWeight: selectedId === m.id ? 700 : 400,
                cursor: 'pointer',
              }}
            />
          </Tooltip>
        ))}
      </Box>
    </Box>
  );
}
