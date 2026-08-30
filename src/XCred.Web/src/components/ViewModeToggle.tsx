import { List, Table2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ViewMode } from '@/hooks/useViewMode';

/** The List/Grid pair of buttons shown next to the search box on the Credentials and Folders
 *  pages, just before the refresh button. */
export default function ViewModeToggle({ viewMode, onChange }: { viewMode: ViewMode; onChange: (mode: ViewMode) => void }) {
  return (
    <div className="flex border border-slate-300 rounded-lg overflow-hidden shrink-0">
      <button onClick={() => onChange('list')} title="List view"
        className={cn('p-2 transition-colors', viewMode === 'list' ? 'bg-indigo-600 text-white' : 'bg-white text-slate-500 hover:bg-slate-50')}>
        <List className="w-4 h-4" />
      </button>
      <button onClick={() => onChange('grid')} title="Grid view"
        className={cn('p-2 transition-colors border-l border-slate-300', viewMode === 'grid' ? 'bg-indigo-600 text-white' : 'bg-white text-slate-500 hover:bg-slate-50')}>
        <Table2 className="w-4 h-4" />
      </button>
    </div>
  );
}
