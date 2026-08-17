import { useState } from 'react';
import { PointerSensor, useSensor, useSensors, type DragEndEvent, type DragStartEvent } from '@dnd-kit/core';

/** Shared by Folders/Credentials pages: a credential row drags with id `cred:<id>`, a folder/
 *  group row (or its "unassigned" bucket) is droppable with id `drop:<id>` / `drop:unassigned`.
 *  A small pointer-move threshold before a drag activates keeps ordinary row clicks (open
 *  credential, press a button) working exactly as before. */
export function useCredentialDnd(onAssign: (credentialId: string, targetId: string | null) => void) {
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 8 } }));

  const handleDragStart = (e: DragStartEvent) => {
    setActiveDragId(String(e.active.id).replace(/^cred:/, ''));
  };

  const handleDragEnd = (e: DragEndEvent) => {
    setActiveDragId(null);
    const { active, over } = e;
    if (!over) return;
    const overId = String(over.id);
    if (!overId.startsWith('drop:')) return;
    const credId = String(active.id).replace(/^cred:/, '');
    const targetRaw = overId.slice('drop:'.length);
    onAssign(credId, targetRaw === 'unassigned' ? null : targetRaw);
  };

  return { sensors, activeDragId, handleDragStart, handleDragEnd };
}
