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
    <div className="flex items-center justify-between mb-4">
      <div className="flex items-center gap-2">
        <button onClick={onPrev} className="p-1 rounded hover:bg-gray-100 cursor-pointer">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h2 className="text-lg font-bold min-w-[140px] text-center">
          {year}年 {month}月
        </h2>
        <button onClick={onNext} className="p-1 rounded hover:bg-gray-100 cursor-pointer">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
      <div className="flex rounded-lg border border-gray-300 overflow-hidden">
        <button
          onClick={() => onViewModeChange('month')}
          className={`px-3 py-1 text-sm cursor-pointer ${viewMode === 'month' ? 'bg-slate-800 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}
        >
          月
        </button>
        <button
          onClick={() => onViewModeChange('week')}
          className={`px-3 py-1 text-sm cursor-pointer ${viewMode === 'week' ? 'bg-slate-800 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}
        >
          週
        </button>
      </div>
    </div>
  );
}
