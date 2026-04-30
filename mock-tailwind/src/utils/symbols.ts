import type { AvailabilityStatus } from '../data/mockData';

type Locale = 'ja' | 'en';

const symbolMap: Record<Locale, Record<string, string>> = {
  ja: { '1': '○', '0': '△', '-1': '×', null: '−' },
  en: { '1': '✓', '0': '?', '-1': '✗', null: '−' },
};

export function getSymbol(status: AvailabilityStatus, locale: Locale = 'ja'): string {
  return symbolMap[locale][String(status)];
}

export function getStatusClasses(status: AvailabilityStatus): { text: string; bg: string } {
  switch (status) {
    case 1:  return { text: 'text-green-600', bg: 'bg-green-100' };
    case 0:  return { text: 'text-yellow-600', bg: 'bg-yellow-100' };
    case -1: return { text: 'text-red-600', bg: 'bg-red-100' };
    default: return { text: 'text-gray-400', bg: 'bg-gray-100' };
  }
}
