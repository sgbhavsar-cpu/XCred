import { useEffect, useMemo, useRef, useState } from 'react';
import * as Popover from '@radix-ui/react-popover';
import { Check, ChevronDown, Plus, Search, X } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface SelectOption {
  value: string;
  label: string;
  /** Secondary text shown muted after the label (e.g. an email address); also searched. */
  hint?: string;
  /** Leading decoration (emoji / icon) shown before the label. */
  icon?: React.ReactNode;
}

/** Search box appears automatically once there are more options than this. */
export const SEARCH_THRESHOLD = 5;
/** The list shows this many rows before it scrolls. */
const MAX_VISIBLE_ROWS = 6;
const ROW_HEIGHT = 36; // px — keep in sync with the `h-9` row class below

/** Case- and punctuation-insensitive, so "wifi" finds "Wi-Fi" and "rdp" finds "Remote Desktop (RDP)". */
const normalize = (s: string) => s.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, '');

/** The one dropdown used across the app (replaces native <select>).
 *   - Type-to-filter search box when there are more than SEARCH_THRESHOLD options.
 *   - Shows at most MAX_VISIBLE_ROWS rows, then scrolls; also never grows taller than the space
 *     actually available on screen (Radix collision handling flips it above the trigger if needed).
 *   - Optional "+" button after the control (`onCreate`) to make a new record without leaving
 *     the current editor; the caller opens its quick-create dialog and selects the new record.
 *   - Keyboard: ↑/↓ move, Enter picks, Esc closes, Home/End jump. */
export default function Select({
  value, onChange, options, placeholder = 'Select…', ariaLabel, name, disabled, className, size = 'md',
  searchable, onCreate, createTitle = 'Create new', emptyText = 'No matches',
}: {
  value: string;
  onChange: (value: string) => void;
  options: SelectOption[];
  placeholder?: string;
  ariaLabel?: string;
  name?: string;
  disabled?: boolean;
  /** Classes for the outer wrapper (width etc.). Defaults to full width. */
  className?: string;
  size?: 'sm' | 'md';
  /** Force the search box on/off; default is "on when there are more than 5 options". */
  searchable?: boolean;
  onCreate?: () => void;
  createTitle?: string;
  emptyText?: string;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [active, setActive] = useState(0);
  const listRef = useRef<HTMLDivElement>(null);
  const showSearch = searchable ?? options.length > SEARCH_THRESHOLD;

  const filtered = useMemo(() => {
    const tokens = normalize(query).split(/\s+/).filter(Boolean);
    if (tokens.length === 0) return options;
    return options.filter(o => {
      const hay = normalize(`${o.label} ${o.hint ?? ''}`);
      return tokens.every(t => hay.includes(t));
    });
  }, [options, query]);

  const selected = options.find(o => o.value === value);

  // Each time the list opens: start with a clean search and the current value highlighted.
  const onOpenChange = (next: boolean) => {
    if (next) {
      setQuery('');
      setActive(Math.max(0, options.findIndex(o => o.value === value)));
    }
    setOpen(next);
  };

  // Keep the highlighted row scrolled into view.
  useEffect(() => {
    if (!open) return;
    listRef.current?.querySelector<HTMLElement>(`[data-index="${active}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [active, open, filtered]);

  const pick = (o: SelectOption) => { onChange(o.value); setOpen(false); };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setActive(i => Math.min(filtered.length - 1, i + 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(i => Math.max(0, i - 1)); }
    else if (e.key === 'Home' && !showSearch) { e.preventDefault(); setActive(0); }
    else if (e.key === 'End' && !showSearch) { e.preventDefault(); setActive(filtered.length - 1); }
    else if (e.key === 'Enter') { e.preventDefault(); const o = filtered[active]; if (o) pick(o); }
  };

  const pad = size === 'sm' ? 'px-2 py-1 text-xs' : 'px-3 py-2 text-sm';

  return (
    <div className={cn('flex items-stretch gap-1.5', className ?? 'w-full')}>
      <Popover.Root open={open} onOpenChange={onOpenChange}>
        <Popover.Trigger asChild>
          <button type="button" role="combobox" aria-expanded={open} aria-haspopup="listbox" aria-label={ariaLabel}
            name={name} disabled={disabled} data-value={value}
            className={cn(
              'flex-1 min-w-0 flex items-center justify-between gap-2 border border-slate-300 rounded-lg bg-white text-left',
              'focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:opacity-60 disabled:cursor-not-allowed', pad)}>
            <span className={cn('truncate', !selected && 'text-slate-400')}>
              {selected ? <>{selected.icon && <span className="mr-1.5">{selected.icon}</span>}{selected.label}</> : placeholder}
            </span>
            <ChevronDown className="w-4 h-4 text-slate-400 shrink-0" />
          </button>
        </Popover.Trigger>

        <Popover.Portal>
          <Popover.Content align="start" sideOffset={4} collisionPadding={12} avoidCollisions
            onOpenAutoFocus={e => { if (!showSearch) { e.preventDefault(); listRef.current?.focus(); } }}
            onKeyDown={onKeyDown}
            style={{ width: 'max(var(--radix-popover-trigger-width), 12rem)', maxWidth: 'calc(100vw - 24px)' }}
            className="z-[70] bg-white border border-slate-200 rounded-lg shadow-lg overflow-hidden">
            {showSearch && (
              <div className="relative border-b border-slate-100">
                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-400 pointer-events-none" />
                <input autoFocus value={query} onChange={e => { setQuery(e.target.value); setActive(0); }}
                  placeholder="Search…" aria-label="Search options"
                  className="w-full pl-8 pr-8 py-2 text-sm focus:outline-none" />
                {query && (
                  <button type="button" title="Clear search" aria-label="Clear search"
                    onClick={() => { setQuery(''); setActive(0); }}
                    className="absolute right-1.5 top-1/2 -translate-y-1/2 p-1 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100">
                    <X className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            )}
            <div ref={listRef} role="listbox" tabIndex={-1} aria-label={ariaLabel}
              className="overflow-y-auto focus:outline-none py-1"
              // Capped at 6 rows, and at whatever room the viewport actually leaves (minus the search box).
              style={{ maxHeight: `min(${MAX_VISIBLE_ROWS * ROW_HEIGHT + 8}px, calc(var(--radix-popover-content-available-height) - ${showSearch ? 48 : 8}px))` }}>
              {filtered.length === 0 && <p className="px-3 py-2 text-sm text-slate-400">{emptyText}</p>}
              {filtered.map((o, i) => (
                <div key={o.value} role="option" aria-selected={o.value === value} data-index={i} data-value={o.value}
                  onClick={() => pick(o)} onMouseMove={() => active !== i && setActive(i)}
                  className={cn('h-9 px-3 flex items-center gap-2 text-sm cursor-pointer',
                    i === active ? 'bg-indigo-50' : '', o.value === value ? 'text-indigo-700 font-medium' : 'text-slate-700')}>
                  <span className="flex-1 min-w-0 truncate">
                    {o.icon && <span className="mr-1.5">{o.icon}</span>}{o.label}
                    {o.hint && <>{' '}<span className="ml-1 text-xs text-slate-400 font-normal">{o.hint}</span></>}
                  </span>
                  {o.value === value && <Check className="w-4 h-4 shrink-0" />}
                </div>
              ))}
            </div>
            {options.length > MAX_VISIBLE_ROWS && (
              <p className="px-3 py-1 text-[11px] text-slate-400 border-t border-slate-100 bg-slate-50">
                {filtered.length === options.length ? `${options.length} items` : `${filtered.length} of ${options.length}`}
              </p>
            )}
          </Popover.Content>
        </Popover.Portal>
      </Popover.Root>

      {onCreate && (
        <button type="button" onClick={onCreate} disabled={disabled} title={createTitle} aria-label={createTitle}
          className={cn('shrink-0 flex items-center justify-center border border-slate-300 rounded-lg bg-white text-indigo-600',
            'hover:bg-indigo-50 hover:border-indigo-300 disabled:opacity-60 transition-colors', size === 'sm' ? 'px-1.5' : 'px-2.5')}>
          <Plus className="w-4 h-4" />
        </button>
      )}
    </div>
  );
}
