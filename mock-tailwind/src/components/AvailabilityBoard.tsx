import { useState } from 'react';
import type { Member, AvailabilityEntry, EventDay, DaySummary, AvailabilityStatus } from '../data/mockData';
import { getSymbol, getStatusClasses } from '../utils/symbols';

interface Props {
  year: number;
  month: number;
  members: Member[];
  availabilities: Record<string, Record<number, AvailabilityEntry>>;
  eventDays: Record<string, EventDay>;
  summary: Record<string, DaySummary>;
  selectedMemberId: number | null;
  thresholdN: number;
  onStatusChange: (date: string, memberId: number, newStatus: AvailabilityStatus) => void;
}

const dayNames = ['日', '月', '火', '水', '木', '金', '土'];

function getDaysInMonth(year: number, month: number): Date[] {
  const days: Date[] = [];
  const lastDay = new Date(year, month, 0).getDate();
  for (let d = 1; d <= lastDay; d++) days.push(new Date(year, month - 1, d));
  return days;
}

function cycleStatus(current: AvailabilityStatus): AvailabilityStatus {
  if (current === null) return 1;
  if (current === 1) return 0;
  if (current === 0) return -1;
  return null;
}

export default function AvailabilityBoard({
  year, month, members, availabilities, eventDays, summary,
  selectedMemberId, thresholdN, onStatusChange,
}: Props) {
  const days = getDaysInMonth(year, month);
  const coreMembers = members.filter(m => m.role === 'owner' || m.role === 'core');
  const subMembers = members.filter(m => m.role === 'sub');

  return (
    <div className="overflow-auto max-h-[70vh] rounded-lg border border-gray-200">
      <table className="w-full text-sm border-collapse">
        <thead className="sticky top-0 z-10 bg-white">
          <tr className="border-b-2 border-gray-300">
            <th className="sticky left-0 z-20 bg-white px-2 py-2 text-left font-bold min-w-[80px]">日付</th>
            <th className="px-1 py-2 text-center font-bold text-green-600 w-10">○</th>
            <th className="px-1 py-2 text-center font-bold text-yellow-600 w-10">△</th>
            <th className="px-1 py-2 text-center font-bold text-red-600 w-10">×</th>
            <th className="px-1 py-2 text-center font-bold text-gray-400 w-10">−</th>
            {coreMembers.map(m => (
              <th key={m.id} className="px-1 py-2 text-center font-semibold text-xs min-w-[56px] group relative">
                <span className="cursor-help">{m.display_name}</span>
              </th>
            ))}
            <th className="border-l-2 border-gray-300 w-2" />
            {subMembers.map(m => (
              <th key={m.id} className="px-1 py-2 text-center font-semibold text-xs min-w-[56px]">
                {m.display_name}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {days.map(date => {
            const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
            const dow = date.getDay();
            const event = eventDays[dateStr];
            const daySummary = summary[dateStr];
            const allOk = daySummary && daySummary.ok === members.length;
            const warning = daySummary && daySummary.ng >= thresholdN;

            let rowBg = '';
            if (event?.confirmed) rowBg = 'bg-blue-50';
            else if (allOk) rowBg = 'bg-green-50';
            else if (warning) rowBg = 'bg-red-50';

            return (
              <tr key={dateStr} className={`border-b border-gray-100 ${rowBg} hover:brightness-[0.97]`}>
                <td className={`sticky left-0 z-[1] px-2 py-1.5 font-semibold text-[13px] ${rowBg || 'bg-white'} ${dow === 0 ? 'text-red-500' : dow === 6 ? 'text-blue-500' : ''}`}>
                  <span className="flex items-center gap-1">
                    {date.getDate()} ({dayNames[dow]})
                    {event && (
                      <span title={`活動日 ${event.start_time}〜${event.end_time}${event.confirmed ? ' (確定)' : ''}`}
                        className={`text-xs ${event.confirmed ? 'text-blue-600' : 'text-gray-400'}`}>📅</span>
                    )}
                    {event?.custom_time && (
                      <span title="活動時間がデフォルトから変更されています" className="text-red-500 text-xs font-bold">❗</span>
                    )}
                  </span>
                </td>

                <td className="text-center text-green-600 font-semibold text-[13px]">{daySummary?.ok ?? 0}</td>
                <td className="text-center text-yellow-600 font-semibold text-[13px]">{daySummary?.maybe ?? 0}</td>
                <td className="text-center text-red-600 font-semibold text-[13px]">{daySummary?.ng ?? 0}</td>
                <td className="text-center text-gray-400 font-semibold text-[13px]">{daySummary?.none ?? 0}</td>

                {coreMembers.map(m => (
                  <StatusCell
                    key={m.id}
                    entry={availabilities[dateStr]?.[m.id]}
                    isEditable={selectedMemberId === m.id}
                    onClick={() => {
                      if (selectedMemberId === m.id) {
                        const entry = availabilities[dateStr]?.[m.id];
                        onStatusChange(dateStr, m.id, cycleStatus(entry?.status ?? null));
                      }
                    }}
                  />
                ))}

                <td className="border-l-2 border-gray-300" />

                {subMembers.map(m => (
                  <StatusCell
                    key={m.id}
                    entry={availabilities[dateStr]?.[m.id]}
                    isEditable={selectedMemberId === m.id}
                    onClick={() => {
                      if (selectedMemberId === m.id) {
                        const entry = availabilities[dateStr]?.[m.id];
                        onStatusChange(dateStr, m.id, cycleStatus(entry?.status ?? null));
                      }
                    }}
                  />
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function StatusCell({ entry, isEditable, onClick }: {
  entry: AvailabilityEntry | undefined;
  isEditable: boolean;
  onClick: () => void;
}) {
  const [showTooltip, setShowTooltip] = useState(false);
  const status = entry?.status ?? null;
  const symbol = getSymbol(status);
  const { text, bg } = getStatusClasses(status);

  return (
    <td
      className={`
        text-center relative
        ${bg} ${isEditable ? 'cursor-pointer ring-2 ring-blue-500 ring-inset' : ''}
        ${isEditable ? 'hover:brightness-[0.9]' : ''}
        transition-all
      `}
      onClick={onClick}
      onMouseEnter={() => setShowTooltip(true)}
      onMouseLeave={() => setShowTooltip(false)}
    >
      <span className={`font-bold text-base select-none ${text}`}>
        {symbol}
      </span>
      {entry?.auto_synced && (
        <span className="text-[9px] text-gray-400 ml-0.5">自動</span>
      )}
      {showTooltip && entry?.comment && (
        <div className="absolute z-20 bottom-full left-1/2 -translate-x-1/2 mb-1 px-2 py-1 bg-gray-800 text-white text-xs rounded whitespace-nowrap">
          {entry.comment}
        </div>
      )}
    </td>
  );
}
