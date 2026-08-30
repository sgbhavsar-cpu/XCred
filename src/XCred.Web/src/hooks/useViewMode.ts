import { useState } from 'react';

export type ViewMode = 'list' | 'grid';

const STORAGE_KEY = 'xcred-view-mode';

/** Shared List/Grid toggle for the Credentials and Folders pages, persisted so switching pages
 *  (or reloading) keeps whichever view the user picked last. */
export function useViewMode() {
  const [viewMode, setViewMode] = useState<ViewMode>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored === 'grid' ? 'grid' : 'list';
    } catch {
      return 'list';
    }
  });

  const setMode = (mode: ViewMode) => {
    setViewMode(mode);
    try { localStorage.setItem(STORAGE_KEY, mode); } catch { /* ignore */ }
  };

  return { viewMode, setViewMode: setMode };
}
