import { useEffect, useState } from 'react';
import { Plus, ChevronRight, ChevronDown, Edit2, Trash2, Check, X, Folder as FolderIcon, FolderOpen, GripVertical, CornerLeftUp } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { DndContext, DragOverlay, MeasuringStrategy, pointerWithin, useDraggable, useDroppable } from '@dnd-kit/core';
import api from '@/api/client';
import { cn, credentialTypeLabel } from '@/lib/utils';
import { useDecryptedCredentials } from '@/hooks/useDecryptedCredentials';
import type { CredentialListItem, DecryptedCredentialMeta } from '@/hooks/useDecryptedCredentials';
import { useCredentialDnd } from '@/hooks/useCredentialDnd';
import CredentialRow from '@/components/CredentialRow';
import SelectionToolbar from '@/components/SelectionToolbar';
import BulkEditModal from '@/components/BulkEditModal';

interface FolderItem {
  id: string;
  name: string;
  parentFolderId: string | null;
  sortOrder: number;
  credentialCount: number;
  children: FolderItem[];
}

interface CredGroupOption { id: string; name: string }

export default function FoldersPage() {
  const navigate = useNavigate();
  const { credentials, decrypted, loading: credsLoading, refetch: refetchCredentials, deleteCredential, bulkAssign } = useDecryptedCredentials();

  const [folders, setFolders] = useState<FolderItem[]>([]);
  const [foldersLoading, setFoldersLoading] = useState(true);
  const [groups, setGroups] = useState<CredGroupOption[]>([]);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newParentId, setNewParentId] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [showBulkEdit, setShowBulkEdit] = useState(false);

  const loadFolders = async () => {
    setFoldersLoading(true);
    try {
      const res = await api.get('/folders');
      setFolders(res.data.data);
    } finally { setFoldersLoading(false); }
  };

  const loadGroups = async () => {
    try {
      const res = await api.get('/credential-groups');
      setGroups(res.data.data);
    } catch { /* the bulk-edit group picker just stays empty; not worth a toast */ }
  };

  useEffect(() => { loadFolders(); loadGroups(); }, []);

  const createFolder = async () => {
    if (!newName.trim()) return;
    try {
      await api.post('/folders', { name: newName.trim(), parentFolderId: newParentId || null });
      await loadFolders();
      setNewName(''); setNewParentId(''); setCreating(false);
      toast.success('Folder created.');
    } catch (err: any) { toast.error(err.response?.data?.error?.message ?? 'Failed to create.'); }
  };

  const updateFolder = async (id: string) => {
    if (!editName.trim()) return;
    // Must resend the folder's current parentFolderId/sortOrder too, not just the new name —
    // the API takes a full replace, so omitting them would silently un-nest this folder and
    // reset its sort position on every rename.
    const current = folderById(folders).get(id);
    try {
      await api.put(`/folders/${id}`, {
        name: editName.trim(),
        parentFolderId: current?.parentFolderId ?? null,
        sortOrder: current?.sortOrder ?? 0,
      });
      await loadFolders();
      setEditingId(null);
      toast.success('Folder renamed.');
    } catch { toast.error('Failed to rename.'); }
  };

  const moveFolder = async (id: string, newParentId: string | null) => {
    const byId = folderById(folders);
    const current = byId.get(id);
    if (!current) return;
    if (current.parentFolderId === newParentId) return; // already there
    if (newParentId && isDescendant(current, newParentId)) {
      toast.error('Cannot move a folder into its own subtree.');
      return;
    }
    try {
      await api.put(`/folders/${id}`, { name: current.name, parentFolderId: newParentId, sortOrder: current.sortOrder });
      await loadFolders();
      toast.success(newParentId ? 'Folder moved.' : 'Moved to top level.');
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Failed to move folder.');
    }
  };

  const deleteFolder = async (id: string) => {
    if (!confirm('Delete this folder? Credentials inside will be moved to "No Folder".')) return;
    try {
      await api.delete(`/folders/${id}`);
      await Promise.all([loadFolders(), refetchCredentials()]);
      toast.success('Folder deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const toggleExpand = (id: string) => setExpanded(prev => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });

  const toggleSelect = (id: string) => setSelectedIds(prev => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });
  const clearSelection = () => setSelectedIds(new Set());

  const handleDeleteCredential = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!confirm('Delete this credential? This cannot be undone.')) return;
    try {
      await deleteCredential(id);
      toast.success('Credential deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  const { sensors, active, handleDragStart, handleDragEnd } = useCredentialDnd(async (kind, dragId, targetId) => {
    if (kind === 'folder') {
      await moveFolder(dragId, targetId);
      return;
    }
    const cred = credentials.find(c => c.id === dragId);
    if (cred && cred.folderId === targetId) return;
    try {
      await bulkAssign([dragId], { updateFolder: true, folderId: targetId });
      toast.success(targetId ? 'Moved to folder.' : 'Removed from folder.');
    } catch { toast.error('Failed to move credential.'); }
  });

  const applyBulkEdit = async (changes: Parameters<typeof bulkAssign>[1]) => {
    try {
      const result = await bulkAssign(Array.from(selectedIds), changes);
      toast.success(`Updated ${result.updated} credential${result.updated !== 1 ? 's' : ''}.`);
      clearSelection();
      setShowBulkEdit(false);
    } catch (err: any) {
      toast.error(err.response?.data?.error?.message ?? 'Bulk edit failed.');
    }
  };

  const byFolder = new Map<string, CredentialListItem[]>();
  const unassigned: CredentialListItem[] = [];
  for (const c of credentials) {
    if (!c.folderId) { unassigned.push(c); continue; }
    if (!byFolder.has(c.folderId)) byFolder.set(c.folderId, []);
    byFolder.get(c.folderId)!.push(c);
  }

  const flatFolders = flattenFolderList(folders);
  const loading = foldersLoading || credsLoading;

  const nothingAtAll = folders.length === 0 && unassigned.length === 0;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Folders</h1>
          <p className="text-slate-500 text-sm">Organise credentials into nested folders</p>
        </div>
        <button onClick={() => setCreating(true)}
          className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
          <Plus className="w-4 h-4" /> New Folder
        </button>
      </div>

      {creating && (
        <div className="bg-white rounded-xl border border-indigo-200 p-4 mb-4 space-y-3">
          <h3 className="text-sm font-semibold text-slate-700">New Folder</h3>
          <input value={newName} onChange={e => setNewName(e.target.value)} placeholder="Folder name"
            autoFocus onKeyDown={e => e.key === 'Enter' && createFolder()}
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          <div>
            <label className="block text-xs text-slate-500 mb-1">Parent Folder (optional)</label>
            <select value={newParentId} onChange={e => setNewParentId(e.target.value)}
              className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
              <option value="">None (top-level)</option>
              {flatFolders.map(f => <option key={f.id} value={f.id}>{f.name}</option>)}
            </select>
          </div>
          <div className="flex gap-2">
            <button onClick={() => { setCreating(false); setNewName(''); setNewParentId(''); }}
              className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">Cancel</button>
            <button onClick={createFolder}
              className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700">Create</button>
          </div>
        </div>
      )}

      <SelectionToolbar count={selectedIds.size} onBulkEdit={() => setShowBulkEdit(true)} onClear={clearSelection} />

      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : nothingAtAll ? (
        <div className="text-center py-16 text-slate-400">
          <FolderOpen className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No folders yet.</p>
          <button onClick={() => setCreating(true)} className="mt-3 text-indigo-600 text-sm hover:underline">Create your first folder →</button>
        </div>
      ) : (
        // pointerWithin, not dnd-kit's default rectIntersection: the "move to top level" zone
        // sits right above the (much taller) folder tree, so overlap-area-based detection would
        // keep resolving to the tree underneath even once the cursor is past the boundary.
        // Pointer-position-based detection follows the cursor itself instead.
        <DndContext sensors={sensors} collisionDetection={pointerWithin}
          measuring={{ droppable: { strategy: MeasuringStrategy.Always } }}
          onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
          {/* Always mounted, same size, at all times (never conditionally rendered/resized) —
              even just appearing or changing height right as a folder drag starts would shift
              every row below it down, moving each folder's actual position out from under
              wherever the drag interaction (or a test) had already measured it a moment
              earlier. Toggling opacity/pointer-events/border color instead keeps layout — and
              therefore every row's position — completely stable through the whole drag. */}
          <DroppableRow id="root" testId="folder-root-drop-zone"
            className={cn(
              'flex items-center gap-2 px-5 py-3 mb-3 rounded-lg border-2 border-dashed text-sm transition-opacity',
              active?.kind === 'folder'
                ? 'border-slate-300 text-slate-500 opacity-100'
                : 'border-transparent text-transparent opacity-0 pointer-events-none select-none',
            )}>
            <CornerLeftUp className="w-4 h-4 shrink-0" /> Drop here to move to the top level
          </DroppableRow>

          <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 overflow-hidden">
            {folders.length > 0 && (
              <FolderTree
                folders={folders} depth={0}
                byFolder={byFolder} decrypted={decrypted}
                expanded={expanded} toggleExpand={toggleExpand}
                editingId={editingId} editName={editName}
                setEditingId={setEditingId} setEditName={setEditName}
                onUpdate={updateFolder} onDelete={deleteFolder}
                onAddCredential={id => navigate(`/credentials/new?folderId=${id}&returnTo=${encodeURIComponent('/folders')}`)}
                onOpenCredential={id => navigate(`/credentials/${id}`)}
                onDeleteCredential={handleDeleteCredential}
                onTagClick={tagId => navigate(`/credentials?tag=${tagId}`)}
                selectedIds={selectedIds} onToggleSelect={toggleSelect}
              />
            )}

            {unassigned.length > 0 && (
              <div>
                {folders.length > 0 && (
                  <DroppableRow id="unassigned" className="px-5 py-2 bg-slate-50">
                    <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Unassigned</p>
                  </DroppableRow>
                )}
                <div className="divide-y divide-slate-100">
                  {unassigned.map(cred => (
                    <CredentialRow key={cred.id} cred={cred} decrypted={decrypted.get(cred.id)}
                      onOpen={() => navigate(`/credentials/${cred.id}`)}
                      onDelete={e => handleDeleteCredential(cred.id, e)}
                      onTagClick={tagId => navigate(`/credentials?tag=${tagId}`)}
                      draggable selectable
                      selected={selectedIds.has(cred.id)}
                      onToggleSelect={() => toggleSelect(cred.id)}
                    />
                  ))}
                </div>
              </div>
            )}
          </div>

          <DragOverlay>
            {active?.kind === 'folder' && (
              <div className="flex items-center gap-2 bg-white border border-indigo-300 shadow-lg rounded-lg px-4 py-2.5 text-sm font-medium text-slate-800">
                <FolderIcon className="w-4 h-4 text-amber-500" /> {folderById(folders).get(active.id)?.name ?? 'Folder'}
              </div>
            )}
            {active?.kind === 'cred' && (
              <div className="flex items-center gap-2 bg-white border border-indigo-300 shadow-lg rounded-lg px-4 py-2.5 text-sm font-medium text-slate-800">
                {credentialTypeLabel(credentials.find(c => c.id === active.id)?.type ?? '')}: {decrypted.get(active.id)?.name ?? 'Credential'}
              </div>
            )}
          </DragOverlay>
        </DndContext>
      )}

      {showBulkEdit && (
        <BulkEditModal count={selectedIds.size} folders={flatFolders} groups={groups}
          onApply={applyBulkEdit} onClose={() => setShowBulkEdit(false)} />
      )}
    </div>
  );
}

function DroppableRow({ id, dragId, onClick, className, children, testId }: {
  id: string; dragId?: string; onClick?: () => void; className: string; children: React.ReactNode; testId?: string;
}) {
  const { setNodeRef: setDropRef, isOver } = useDroppable({ id: `drop:${id}` });
  const { attributes, listeners, setNodeRef: setDragRef, isDragging } = useDraggable({
    id: dragId ?? `__nodrag__${id}`,
    disabled: !dragId,
  });
  const setNodeRef = (node: HTMLElement | null) => { setDropRef(node); setDragRef(node); };
  return (
    <div ref={setNodeRef} onClick={onClick} data-testid={testId}
      className={cn(className, isOver && 'ring-2 ring-inset ring-indigo-400 bg-indigo-50/60', isDragging && 'opacity-40')}>
      {dragId && (
        <button type="button" {...attributes} {...listeners}
          onClick={e => e.stopPropagation()}
          className="shrink-0 text-slate-300 hover:text-slate-500 cursor-grab active:cursor-grabbing touch-none" title="Drag to move">
          <GripVertical className="w-4 h-4" />
        </button>
      )}
      {children}
    </div>
  );
}

function FolderTree({
  folders, depth, byFolder, decrypted, expanded, toggleExpand,
  editingId, editName, setEditingId, setEditName, onUpdate, onDelete,
  onAddCredential, onOpenCredential, onDeleteCredential, onTagClick,
  selectedIds, onToggleSelect,
}: {
  folders: FolderItem[]; depth: number;
  byFolder: Map<string, CredentialListItem[]>; decrypted: Map<string, DecryptedCredentialMeta>;
  expanded: Set<string>; toggleExpand: (id: string) => void;
  editingId: string | null; editName: string;
  setEditingId: (id: string | null) => void; setEditName: (name: string) => void;
  onUpdate: (id: string) => void; onDelete: (id: string) => void;
  onAddCredential: (id: string) => void; onOpenCredential: (id: string) => void;
  onDeleteCredential: (id: string, e: React.MouseEvent) => void; onTagClick: (tagId: string) => void;
  selectedIds: Set<string>; onToggleSelect: (id: string) => void;
}) {
  return (
    <>
      {folders.map(folder => {
        const members = byFolder.get(folder.id) ?? [];
        const isOpen = expanded.has(folder.id);
        const isEditing = editingId === folder.id;
        return (
          <div key={folder.id}>
            <DroppableRow id={folder.id} dragId={isEditing ? undefined : `folder:${folder.id}`}
              onClick={() => !isEditing && toggleExpand(folder.id)}
              className={cn('flex items-center gap-3 px-5 py-3.5', depth > 0 && 'bg-slate-50/60', !isEditing && 'cursor-pointer hover:bg-slate-50 transition-colors')}>
              {depth > 0 && <div style={{ width: Math.min(depth, 4) * 20 }} className="shrink-0" />}
              {isOpen ? <ChevronDown className="w-4 h-4 text-slate-400 shrink-0" /> : <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />}

              <div className={cn('w-9 h-9 rounded-lg flex items-center justify-center shrink-0', depth === 0 ? 'bg-amber-100' : 'bg-amber-50')}>
                <FolderIcon className={cn('w-4.5 h-4.5', depth === 0 ? 'text-amber-600' : 'text-amber-400')} />
              </div>

              {isEditing ? (
                <>
                  <input value={editName} onChange={e => setEditName(e.target.value)} autoFocus
                    onClick={e => e.stopPropagation()}
                    onKeyDown={e => { if (e.key === 'Enter') onUpdate(folder.id); if (e.key === 'Escape') setEditingId(null); }}
                    className="flex-1 px-3 py-1.5 border border-indigo-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                  <button onClick={e => { e.stopPropagation(); onUpdate(folder.id); }} className="p-1.5 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors"><Check className="w-3.5 h-3.5" /></button>
                  <button onClick={e => { e.stopPropagation(); setEditingId(null); }} className="p-1.5 text-slate-400 hover:text-slate-600 transition-colors"><X className="w-3.5 h-3.5" /></button>
                </>
              ) : (
                <>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">{folder.name}</p>
                    <p className="text-xs text-slate-400 mt-0.5">
                      {members.length === 0 ? 'Empty' : `${members.length} credential${members.length !== 1 ? 's' : ''}`}
                    </p>
                  </div>

                  <div className="flex items-center gap-1 shrink-0">
                    <button onClick={e => { e.stopPropagation(); onAddCredential(folder.id); }}
                      className="p-1.5 rounded hover:bg-indigo-50 text-slate-400 hover:text-indigo-600 transition-colors" title="Add credential to this folder">
                      <Plus className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); setEditingId(folder.id); setEditName(folder.name); }}
                      className="p-1.5 rounded hover:bg-indigo-50 text-slate-400 hover:text-indigo-600 transition-colors" title="Rename">
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); onDelete(folder.id); }}
                      className="p-1.5 rounded hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors" title="Delete">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </>
              )}
            </DroppableRow>

            {isOpen && !isEditing && (
              members.length === 0 ? (
                <div className="px-5 py-4 text-xs text-slate-400 bg-slate-50/50" style={{ paddingLeft: 20 * Math.min(depth, 4) + 56 }}>
                  No credentials directly in this folder yet. <button onClick={() => onAddCredential(folder.id)} className="text-indigo-600 hover:underline">Add one</button>.
                </div>
              ) : (
                <div className="divide-y divide-slate-100">
                  {members.map(cred => (
                    <CredentialRow key={cred.id} cred={cred} decrypted={decrypted.get(cred.id)}
                      onOpen={() => onOpenCredential(cred.id)}
                      onDelete={e => onDeleteCredential(cred.id, e)}
                      onTagClick={onTagClick}
                      indent draggable selectable
                      selected={selectedIds.has(cred.id)}
                      onToggleSelect={() => onToggleSelect(cred.id)}
                    />
                  ))}
                </div>
              )
            )}

            {folder.children.length > 0 && (
              <div className="border-t border-slate-100">
                <FolderTree
                  folders={folder.children} depth={depth + 1}
                  byFolder={byFolder} decrypted={decrypted}
                  expanded={expanded} toggleExpand={toggleExpand}
                  editingId={editingId} editName={editName}
                  setEditingId={setEditingId} setEditName={setEditName}
                  onUpdate={onUpdate} onDelete={onDelete}
                  onAddCredential={onAddCredential} onOpenCredential={onOpenCredential}
                  onDeleteCredential={onDeleteCredential} onTagClick={onTagClick}
                  selectedIds={selectedIds} onToggleSelect={onToggleSelect}
                />
              </div>
            )}
          </div>
        );
      })}
    </>
  );
}

function flattenFolderList(folders: FolderItem[], prefix = ''): Array<{ id: string; name: string }> {
  const result: Array<{ id: string; name: string }> = [];
  for (const f of folders) {
    result.push({ id: f.id, name: prefix + f.name });
    if (f.children.length) result.push(...flattenFolderList(f.children, prefix + f.name + ' / '));
  }
  return result;
}

function folderById(folders: FolderItem[]): Map<string, FolderItem> {
  const map = new Map<string, FolderItem>();
  (function index(list: FolderItem[]) {
    for (const f of list) { map.set(f.id, f); index(f.children); }
  })(folders);
  return map;
}

/** True if candidateId is folder itself or anywhere in its subtree — used to block dropping a
 *  folder onto one of its own descendants, which would otherwise create a cycle in the tree. */
function isDescendant(folder: FolderItem, candidateId: string): boolean {
  if (folder.id === candidateId) return true;
  return folder.children.some(child => isDescendant(child, candidateId));
}
