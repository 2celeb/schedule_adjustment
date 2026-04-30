import { useState } from 'react';
import type { Member } from '../data/mockData';

interface Props {
  members: Member[];
  selectedId: number | null;
  onSelect: (id: number) => void;
}

function getRoleBadge(role: Member['role']) {
  switch (role) {
    case 'owner': return <span className="ml-1 text-[10px] px-1 py-0.5 rounded bg-blue-100 text-blue-700">Owner</span>;
    case 'core': return <span className="ml-1 text-[10px] px-1 py-0.5 rounded bg-green-100 text-green-700">Core</span>;
    default: return <span className="ml-1 text-[10px] px-1 py-0.5 rounded bg-gray-100 text-gray-500">Sub</span>;
  }
}

export default function MemberSelector({ members, selectedId, onSelect }: Props) {
  const [hoveredId, setHoveredId] = useState<number | null>(null);

  return (
    <div className="mb-4">
      <p className="text-sm text-gray-500 mb-2">メンバーを選択してください</p>
      <div className="flex flex-wrap gap-2">
        {members.map(m => (
          <div key={m.id} className="relative">
            <button
              onClick={() => onSelect(m.id)}
              onMouseEnter={() => setHoveredId(m.id)}
              onMouseLeave={() => setHoveredId(null)}
              className={`
                px-3 py-1.5 rounded-full text-sm font-medium border transition-all cursor-pointer
                ${selectedId === m.id
                  ? 'bg-slate-800 text-white border-slate-800'
                  : 'bg-white text-gray-700 border-gray-300 hover:border-gray-500'
                }
              `}
            >
              <span className="flex items-center gap-1">
                {m.display_name}
                {m.auth_locked && <span className="text-xs">🔒</span>}
                {getRoleBadge(m.role)}
              </span>
            </button>
            {hoveredId === m.id && (
              <div className="absolute z-10 bottom-full left-1/2 -translate-x-1/2 mb-1 px-2 py-1 bg-gray-800 text-white text-xs rounded whitespace-nowrap">
                Discord: {m.discord_screen_name}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
