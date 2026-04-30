import { useState, useMemo } from 'react';
import MemberSelector from './components/MemberSelector';
import AvailabilityBoard from './components/AvailabilityBoard';
import MonthNavigator from './components/MonthNavigator';
import {
  members, groupInfo, generateAvailabilities, generateEventDays, computeSummary,
} from './data/mockData';
import type { AvailabilityStatus } from './data/mockData';

export default function App() {
  const [selectedMemberId, setSelectedMemberId] = useState<number | null>(null);
  const [year, setYear] = useState(2025);
  const [month, setMonth] = useState(7);
  const [viewMode, setViewMode] = useState<'month' | 'week'>('month');
  const [availabilities, setAvailabilities] = useState(() => generateAvailabilities());
  const eventDays = useMemo(() => generateEventDays(), []);
  const summary = useMemo(() => computeSummary(availabilities), [availabilities]);

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

  return (
    <div className="min-h-screen bg-gray-50">
      {/* ヘッダー */}
      <header className="bg-slate-800 text-white px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xl">📅</span>
          <h1 className="text-lg font-bold">{groupInfo.name} - スケジュール調整</h1>
        </div>
        <span className="text-xs px-2 py-1 bg-amber-500 text-white rounded">Tailwind版モック</span>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-6">
        {/* メンバー選択 */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 mb-4">
          <MemberSelector
            members={members}
            selectedId={selectedMemberId}
            onSelect={setSelectedMemberId}
          />
        </div>

        {/* カレンダー */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <MonthNavigator
            year={year}
            month={month}
            viewMode={viewMode}
            onPrev={handlePrev}
            onNext={handleNext}
            onViewModeChange={setViewMode}
          />

          <AvailabilityBoard
            year={year}
            month={month}
            members={members}
            availabilities={availabilities}
            eventDays={eventDays}
            summary={summary}
            selectedMemberId={selectedMemberId}
            thresholdN={groupInfo.threshold_n}
            onStatusChange={handleStatusChange}
          />

          {/* 凡例 */}
          <div className="mt-4 flex flex-wrap gap-3 text-xs text-gray-600">
            <span className="flex items-center gap-1"><span className="w-4 h-4 bg-green-100 border border-gray-300 rounded-sm" /> ○ 参加可能</span>
            <span className="flex items-center gap-1"><span className="w-4 h-4 bg-yellow-100 border border-gray-300 rounded-sm" /> △ 未定</span>
            <span className="flex items-center gap-1"><span className="w-4 h-4 bg-red-100 border border-gray-300 rounded-sm" /> × 参加不可</span>
            <span className="flex items-center gap-1"><span className="w-4 h-4 bg-gray-100 border border-gray-300 rounded-sm" /> − 未入力</span>
            <span className="flex items-center gap-1"><span className="w-4 h-4 bg-blue-50 border border-gray-300 rounded-sm" /> 活動日（確定）</span>
            <span className="flex items-center gap-1"><span className="w-4 h-4 bg-red-50 border border-gray-300 rounded-sm" /> 警告（×が{groupInfo.threshold_n}人以上）</span>
          </div>
        </div>
      </main>
    </div>
  );
}
