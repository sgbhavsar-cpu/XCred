import { Pencil, X } from 'lucide-react';

/** Sticky bar shown whenever 1+ credentials are checked, on both Credentials and Folders. */
export default function SelectionToolbar({ count, onBulkEdit, onClear }: {
  count: number;
  onBulkEdit: () => void;
  onClear: () => void;
}) {
  if (count === 0) return null;
  return (
    <div className="sticky top-0 z-10 flex items-center gap-3 bg-indigo-600 text-white px-4 py-2.5 rounded-lg mb-3 shadow-sm">
      <span className="text-sm font-medium">{count} selected</span>
      <button onClick={onBulkEdit}
        className="flex items-center gap-1.5 bg-white/15 hover:bg-white/25 px-3 py-1 rounded-md text-sm font-medium transition-colors">
        <Pencil className="w-3.5 h-3.5" /> Bulk Edit
      </button>
      <button onClick={onClear} className="ml-auto p-1 hover:bg-white/15 rounded transition-colors" title="Clear selection">
        <X className="w-4 h-4" />
      </button>
    </div>
  );
}
