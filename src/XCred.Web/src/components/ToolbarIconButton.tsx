import type { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

/** Small square icon-only toolbar button — same size/shape as the Credentials page's existing
 *  refresh button, reused for filter toggles (active = indigo highlight) and plain actions
 *  like CSV export (no `active` prop). No label text; callers must set `title` for a tooltip. */
export default function ToolbarIconButton({ icon: Icon, active, onClick, title, disabled }: {
  icon: LucideIcon;
  active?: boolean;
  onClick: () => void;
  title: string;
  disabled?: boolean;
}) {
  return (
    <button onClick={onClick} disabled={disabled} title={title}
      className={cn(
        'p-2 border rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed',
        active ? 'border-indigo-500 bg-indigo-50 text-indigo-600' : 'border-slate-300 text-slate-500 hover:bg-slate-50'
      )}>
      <Icon className="w-4 h-4" />
    </button>
  );
}
