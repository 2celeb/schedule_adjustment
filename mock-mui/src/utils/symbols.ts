import type { AvailabilityStatus } from '../data/mockData';

type Locale = 'ja' | 'en';

const symbolMap: Record<Locale, Record<string, string>> = {
  ja: { '1': '○', '0': '△', '-1': '×', null: '−' },
  en: { '1': '✓', '0': '?', '-1': '✗', null: '−' },
};

export function getSymbol(status: AvailabilityStatus, locale: Locale = 'ja'): string {
  return symbolMap[locale][String(status)];
}

export function getStatusColor(status: AvailabilityStatus): string {
  switch (status) {
    case 1: return '#22c55e';   // 緑
    case 0: return '#eab308';   // 黄
    case -1: return '#ef4444';  // 赤
    default: return '#9ca3af';  // グレー
  }
}

export function getStatusBgColor(status: AvailabilityStatus): string {
  switch (status) {
    case 1: return '#dcfce7';
    case 0: return '#fef9c3';
    case -1: return '#fee2e2';
    default: return '#f3f4f6';
  }
}
