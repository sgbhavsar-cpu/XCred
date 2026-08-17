import { useState } from 'react';
import { PointerSensor, useSensor, useSensors, type DragEndEvent, type DragStartEvent } from '@dnd-kit/core';

export type DragKind = 'cred' | 'folder';

/** Shared by Folders/Credentials pages. A draggable row's id is "<kind>:<id>" — "cred:<id>" for
 *  a credential, "folder:<id>" for a folder row that's itself being moved. A drop target's id
 *  is "drop:<id>", or the sentinel buckets "drop:unassigned" (clear a credential's folder/
 *  group) and "drop:root" (move a folder to the top level) — both resolve to a null target.
 *  A small pointer-move threshold before a drag activates keeps ordinary row clicks (open
 *  credential, expand folder, press a button) working exactly as before. */
export function useCredentialDnd(onDrop: (kind: DragKind, dragId: string, targetId: string | null) => void) {
  const [active, setActive] = useState<{ kind: DragKind; id: string } | null>(null);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 8 } }));

  const parseDragId = (raw: string): { kind: DragKind; id: string } => {
    if (raw.startsWith('folder:')) return { kind: 'folder', id: raw.slice('folder:'.length) };
    return { kind: 'cred', id: raw.replace(/^cred:/, '') };
  };

  const handleDragStart = (e: DragStartEvent) => setActive(parseDragId(String(e.active.id)));

  const handleDragEnd = (e: DragEndEvent) => {
    setActive(null);
    const { active: a, over } = e;
    if (!over) return;
    const overId = String(over.id);
    if (!overId.startsWith('drop:')) return;
    const { kind, id } = parseDragId(String(a.id));
    const targetRaw = overId.slice('drop:'.length);
    onDrop(kind, id, targetRaw === 'unassigned' || targetRaw === 'root' ? null : targetRaw);
  };

  return { sensors, active, handleDragStart, handleDragEnd };
}
