import { useEffect, useState } from 'react';
import { Plus, Users, UserPlus, UserMinus, Trash2, ChevronDown, ChevronRight } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '@/api/client';
import { useAuthStore } from '@/store/authStore';
import { formatDate } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface GroupMember { userId: string; username: string; email: string; role: string; joinedAt: string }
interface Group { id: string; name: string; description: string | null; memberCount: number; myRole: string; createdAt: string; members: GroupMember[] }
interface AvailableUser { id: string; username: string; email: string }

export default function GroupsPage() {
  const { isAdmin } = useAuthStore();
  const [groups, setGroups] = useState<Group[]>([]);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [availableUsers, setAvailableUsers] = useState<AvailableUser[]>([]);
  const [addingMember, setAddingMember] = useState<{ groupId: string; userId: string } | null>(null);

  const load = async () => {
    try {
      const res = await api.get('/groups');
      setGroups(res.data.data);
    } finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const loadUsers = async () => {
    const res = await api.get('/admin/users').catch(() => null);
    if (res) setAvailableUsers(res.data.data.filter((u: any) => u.isActive && u.isApproved));
  };

  const toggleExpand = (id: string) => setExpanded(prev => {
    const next = new Set(prev);
    next.has(id) ? next.delete(id) : next.add(id);
    return next;
  });

  const createGroup = async () => {
    if (!newName.trim()) return;
    try {
      await api.post('/groups', { name: newName.trim(), description: newDesc || null, memberIds: [] });
      await load();
      setNewName(''); setNewDesc(''); setShowCreate(false);
      toast.success('Group created.');
    } catch (err: any) { toast.error(err.response?.data?.error?.message ?? 'Failed to create.'); }
  };

  const addMember = async (groupId: string, userId: string) => {
    try {
      await api.post(`/groups/${groupId}/members/${userId}`);
      await load();
      setAddingMember(null);
      toast.success('Member added.');
    } catch (err: any) { toast.error(err.response?.data?.error?.message ?? 'Failed to add member.'); }
  };

  const removeMember = async (groupId: string, userId: string, username: string) => {
    if (!confirm(`Remove ${username} from this group?`)) return;
    try {
      await api.delete(`/groups/${groupId}/members/${userId}`);
      await load();
      toast.success('Member removed.');
    } catch { toast.error('Failed to remove.'); }
  };

  const deleteGroup = async (id: string) => {
    if (!confirm('Delete this group?')) return;
    try {
      await api.delete(`/groups/${id}`);
      await load();
      toast.success('Group deleted.');
    } catch { toast.error('Failed to delete.'); }
  };

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Groups</h1>
          <p className="text-slate-500 text-sm">Manage team groups and shared access</p>
        </div>
        <button onClick={() => setShowCreate(true)} className="flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
          <Plus className="w-4 h-4" /> New Group
        </button>
      </div>

      {showCreate && (
        <div className="bg-white rounded-xl border border-indigo-200 p-4 mb-4 space-y-3">
          <h3 className="text-sm font-semibold text-slate-700">Create Group</h3>
          <input value={newName} onChange={e => setNewName(e.target.value)} placeholder="Group name" autoFocus
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          <input value={newDesc} onChange={e => setNewDesc(e.target.value)} placeholder="Description (optional)"
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          <div className="flex gap-2">
            <button onClick={() => { setShowCreate(false); setNewName(''); setNewDesc(''); }}
              className="flex-1 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">Cancel</button>
            <button onClick={createGroup} className="flex-1 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700">Create</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600" /></div>
      ) : groups.length === 0 ? (
        <div className="text-center py-16 text-slate-400">
          <Users className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No groups yet.</p>
          <button onClick={() => setShowCreate(true)} className="mt-3 text-indigo-600 text-sm hover:underline">Create your first group →</button>
        </div>
      ) : (
        <div className="space-y-3">
          {groups.map(group => (
            <div key={group.id} className="bg-white rounded-xl border border-slate-200 overflow-hidden">
              <div className="flex items-center gap-3 px-5 py-4 cursor-pointer hover:bg-slate-50 transition-colors" onClick={() => toggleExpand(group.id)}>
                <div className="w-9 h-9 bg-indigo-100 rounded-lg flex items-center justify-center shrink-0">
                  <Users className="w-4 h-4 text-indigo-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="font-semibold text-slate-800">{group.name}</p>
                    <span className={cn('text-xs px-1.5 py-0.5 rounded font-medium', group.myRole === 'Admin' ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-600')}>{group.myRole}</span>
                  </div>
                  {group.description && <p className="text-xs text-slate-400 truncate">{group.description}</p>}
                  <p className="text-xs text-slate-400">{group.memberCount} member{group.memberCount !== 1 ? 's' : ''} · Created {formatDate(group.createdAt)}</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {(group.myRole === 'Admin' || isAdmin()) && (
                    <button onClick={e => { e.stopPropagation(); deleteGroup(group.id); }}
                      className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                  {expanded.has(group.id) ? <ChevronDown className="w-4 h-4 text-slate-400" /> : <ChevronRight className="w-4 h-4 text-slate-400" />}
                </div>
              </div>

              {expanded.has(group.id) && (
                <div className="border-t border-slate-100">
                  <div className="px-5 py-3 bg-slate-50 flex items-center justify-between">
                    <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Members</p>
                    {(group.myRole === 'Admin' || isAdmin()) && (
                      <button onClick={() => { loadUsers(); setAddingMember({ groupId: group.id, userId: '' }); }}
                        className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-medium">
                        <UserPlus className="w-3.5 h-3.5" /> Add Member
                      </button>
                    )}
                  </div>

                  {addingMember?.groupId === group.id && (
                    <div className="px-5 py-3 flex gap-2 border-t border-slate-100 bg-indigo-50/50">
                      <select value={addingMember.userId}
                        onChange={e => setAddingMember({ groupId: group.id, userId: e.target.value })}
                        className="flex-1 px-3 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                        <option value="">Select user…</option>
                        {availableUsers.filter(u => !group.members.some(m => m.userId === u.id)).map(u => (
                          <option key={u.id} value={u.id}>{u.username} ({u.email})</option>
                        ))}
                      </select>
                      <button onClick={() => addingMember.userId && addMember(group.id, addingMember.userId)}
                        className="px-3 py-1.5 bg-indigo-600 text-white rounded-lg text-sm hover:bg-indigo-700">Add</button>
                      <button onClick={() => setAddingMember(null)} className="px-3 py-1.5 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">Cancel</button>
                    </div>
                  )}

                  <div className="divide-y divide-slate-100">
                    {group.members.map(member => (
                      <div key={member.userId} className="px-5 py-3 flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <div className="w-7 h-7 rounded-full bg-slate-200 flex items-center justify-center text-xs font-semibold text-slate-600">
                            {member.username[0].toUpperCase()}
                          </div>
                          <div>
                            <p className="text-sm font-medium text-slate-800">{member.username}</p>
                            <p className="text-xs text-slate-400">{member.email}</p>
                          </div>
                          <span className={cn('text-xs px-1.5 py-0.5 rounded font-medium ml-1', member.role === 'Admin' ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-600')}>
                            {member.role}
                          </span>
                        </div>
                        {(group.myRole === 'Admin' || isAdmin()) && (
                          <button onClick={() => removeMember(group.id, member.userId, member.username)}
                            className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
                            <UserMinus className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
