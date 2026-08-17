import { CheckSquare, Square } from 'lucide-react';

/** Toggles between selecting every currently-visible (filtered) credential and clearing the
 *  selection — "visible" is whatever the host page currently has on screen, respecting its own
 *  search/type/context filters, so this only ever selects what the user can actually see. */
export default function SelectAllButton({ allSelected, onToggle, disabled }: {
  allSelected: boolean;
  onToggle: () => void;
  disabled?: boolean;
}) {
  return (
    <button onClick={onToggle} disabled={disabled} title={allSelected ? 'Deselect all' : 'Select all visible credentials'}
      className="flex items-center gap-2 px-3 py-2 border border-slate-300 rounded-lg text-sm text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors">
      {allSelected ? <CheckSquare className="w-4 h-4 text-indigo-600" /> : <Square className="w-4 h-4" />}
      {allSelected ? 'Deselect All' : 'Select All'}
    </button>
  );
}
