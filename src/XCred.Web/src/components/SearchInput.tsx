import { Search, X } from 'lucide-react';
import { cn } from '@/lib/utils';

/** The one search box used app-wide: magnifier on the left and, once there is text, an "X" button
 *  on the right that clears it with a single click (focus stays in the box so typing can resume).
 *  Escape clears too. */
export default function SearchInput({ value, onChange, placeholder, className, autoFocus, ariaLabel }: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
  autoFocus?: boolean;
  ariaLabel?: string;
}) {
  return (
    <div className={cn('relative', className)}>
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
      <input type="text" value={value} autoFocus={autoFocus} aria-label={ariaLabel ?? placeholder}
        onChange={e => onChange(e.target.value)}
        onKeyDown={e => { if (e.key === 'Escape' && value) { e.stopPropagation(); onChange(''); } }}
        placeholder={placeholder}
        className="w-full pl-9 pr-9 py-2 border border-slate-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500" />
      {value && (
        <button type="button" onClick={e => { onChange(''); e.currentTarget.parentElement?.querySelector('input')?.focus(); }}
          title="Clear search" aria-label="Clear search"
          className="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors">
          <X className="w-3.5 h-3.5" />
        </button>
      )}
    </div>
  );
}
