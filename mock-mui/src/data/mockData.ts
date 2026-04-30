// ダミーデータ: Availability_Board 表示用

export type Role = 'owner' | 'core' | 'sub';
export type AvailabilityStatus = 1 | 0 | -1 | null; // ○=1, △=0, ×=-1, −=null

export interface Member {
  id: number;
  display_name: string;
  discord_screen_name: string;
  role: Role;
  auth_locked: boolean;
}

export interface AvailabilityEntry {
  status: AvailabilityStatus;
  comment: string | null;
  auto_synced: boolean;
}

export interface EventDay {
  start_time: string;
  end_time: string;
  confirmed: boolean;
  custom_time: boolean;
}

export interface DaySummary {
  ok: number;
  maybe: number;
  ng: number;
  none: number;
}

export const groupInfo = {
  id: 1,
  name: 'サッカーチーム',
  locale: 'ja' as const,
  threshold_n: 3,
  threshold_target: 'core' as const,
  default_start_time: '19:00',
  default_end_time: '22:00',
};

export const members: Member[] = [
  { id: 1, display_name: 'えれん', discord_screen_name: 'eren_discord', role: 'owner', auth_locked: true },
  { id: 2, display_name: 'りふぃ', discord_screen_name: 'rifyi_discord', role: 'core', auth_locked: true },
  { id: 3, display_name: 'いおりん', discord_screen_name: 'iorin_discord', role: 'core', auth_locked: false },
  { id: 4, display_name: 'ちたん', discord_screen_name: 'chitan_discord', role: 'core', auth_locked: false },
  { id: 5, display_name: 'まさき', discord_screen_name: 'masaki_discord', role: 'core', auth_locked: false },
  { id: 6, display_name: 'ゆうと', discord_screen_name: 'yuuto_discord', role: 'sub', auth_locked: false },
  { id: 7, display_name: 'あかり', discord_screen_name: 'akari_discord', role: 'sub', auth_locked: false },
  { id: 8, display_name: 'けんた', discord_screen_name: 'kenta_discord', role: 'sub', auth_locked: false },
];

// 2025年7月のダミーデータを生成
export function generateAvailabilities(): Record<string, Record<number, AvailabilityEntry>> {
  const data: Record<string, Record<number, AvailabilityEntry>> = {};
  const statuses: AvailabilityStatus[] = [1, 0, -1, null];
  const comments = ['出張のため', '体調不良', '家族の予定', '仕事が遅くなりそう', null];

  for (let day = 1; day <= 31; day++) {
    const dateStr = `2025-07-${String(day).padStart(2, '0')}`;
    data[dateStr] = {};
    for (const member of members) {
      const seed = (member.id * 31 + day * 7) % 17;
      const status = statuses[seed % 4];
      data[dateStr][member.id] = {
        status,
        comment: status === -1 || status === 0 ? comments[seed % 5] : null,
        auto_synced: status === -1 && seed % 3 === 0,
      };
    }
  }
  return data;
}

export function generateEventDays(): Record<string, EventDay> {
  return {
    '2025-07-08': { start_time: '19:00', end_time: '22:00', confirmed: true, custom_time: false },
    '2025-07-10': { start_time: '19:00', end_time: '22:00', confirmed: true, custom_time: false },
    '2025-07-15': { start_time: '20:00', end_time: '23:00', confirmed: true, custom_time: true },
    '2025-07-17': { start_time: '19:00', end_time: '22:00', confirmed: false, custom_time: false },
    '2025-07-22': { start_time: '19:00', end_time: '22:00', confirmed: false, custom_time: false },
    '2025-07-24': { start_time: '19:00', end_time: '22:00', confirmed: false, custom_time: false },
  };
}

export function computeSummary(
  availabilities: Record<string, Record<number, AvailabilityEntry>>
): Record<string, DaySummary> {
  const summary: Record<string, DaySummary> = {};
  for (const [date, entries] of Object.entries(availabilities)) {
    let ok = 0, maybe = 0, ng = 0, none = 0;
    for (const member of members) {
      const entry = entries[member.id];
      if (!entry || entry.status === null) none++;
      else if (entry.status === 1) ok++;
      else if (entry.status === 0) maybe++;
      else if (entry.status === -1) ng++;
    }
    summary[date] = { ok, maybe, ng, none };
  }
  return summary;
}
