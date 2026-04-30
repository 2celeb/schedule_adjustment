// Google カレンダーから取得した予定枠のダミーデータ（時間枠のみ、タイトル・詳細なし）

export interface CalendarSlot {
  start: string; // "HH:mm"
  end: string;   // "HH:mm"
}

// メンバーごと・日付ごとの予定枠
export function generateCalendarSlots(memberId: number): Record<string, CalendarSlot[]> {
  const slots: Record<string, CalendarSlot[]> = {};

  // メンバーIDに基づいてバリエーションを生成
  const patterns: CalendarSlot[][] = [
    [{ start: '10:00', end: '12:00' }],
    [{ start: '13:00', end: '15:00' }, { start: '18:00', end: '20:00' }],
    [{ start: '09:00', end: '17:00' }],
    [{ start: '19:00', end: '21:30' }],
    [{ start: '14:00', end: '16:00' }],
    [],
  ];

  for (let day = 1; day <= 31; day++) {
    const dateStr = `2025-07-${String(day).padStart(2, '0')}`;
    const seed = (memberId * 13 + day * 5) % 11;

    if (seed < 6) {
      const patternIdx = (memberId + day) % patterns.length;
      const pattern = patterns[patternIdx];
      if (pattern.length > 0) {
        slots[dateStr] = pattern;
      }
    }
    // seed >= 6 の場合は予定なし（エントリなし）
  }

  return slots;
}
