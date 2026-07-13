import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from '@/store/authStore';
import AppLayout from '@/components/layout/AppLayout';
import LoginPage from '@/pages/auth/LoginPage';
import RegisterPage from '@/pages/auth/RegisterPage';
import DashboardPage from '@/pages/dashboard/DashboardPage';
import CredentialsPage from '@/pages/credentials/CredentialsPage';
import CredentialFormPage from '@/pages/credentials/CredentialFormPage';
import CredentialDetailPage from '@/pages/credentials/CredentialDetailPage';
import SharesPage from '@/pages/shares/SharesPage';
import TagsPage from '@/pages/tags/TagsPage';
import FoldersPage from '@/pages/folders/FoldersPage';
import GroupsPage from '@/pages/groups/GroupsPage';
import CredentialGroupDetailPage from '@/pages/credential-groups/CredentialGroupDetailPage';
import SettingsPage from '@/pages/settings/SettingsPage';
import AdminPage from '@/pages/admin/AdminPage';

function RequireAuth({ children }: { children: React.ReactNode }) {
  const { accessToken, privateKey } = useAuthStore();
  if (!accessToken || !privateKey) return <Navigate to="/login" replace />;
  return <AppLayout>{children}</AppLayout>;
}

function RequireAdmin({ children }: { children: React.ReactNode }) {
  const { isAdmin } = useAuthStore();
  if (!isAdmin()) return <Navigate to="/dashboard" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <BrowserRouter>
      <Toaster position="top-right" toastOptions={{ duration: 4000 }} />
      <Routes>
        {/* Public */}
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />

        {/* Dashboard */}
        <Route path="/dashboard" element={<RequireAuth><DashboardPage /></RequireAuth>} />

        {/* Credentials */}
        <Route path="/credentials" element={<RequireAuth><CredentialsPage /></RequireAuth>} />
        <Route path="/credentials/new" element={<RequireAuth><CredentialFormPage /></RequireAuth>} />
        <Route path="/credentials/:id" element={<RequireAuth><CredentialDetailPage /></RequireAuth>} />
        <Route path="/credentials/:id/edit" element={<RequireAuth><CredentialFormPage /></RequireAuth>} />

        {/* Sharing */}
        <Route path="/shares" element={<RequireAuth><SharesPage /></RequireAuth>} />

        {/* Organisation */}
        <Route path="/folders" element={<RequireAuth><FoldersPage /></RequireAuth>} />
        <Route path="/credential-groups/:id" element={<RequireAuth><CredentialGroupDetailPage /></RequireAuth>} />
        <Route path="/groups" element={<RequireAuth><GroupsPage /></RequireAuth>} />
        <Route path="/tags" element={<RequireAuth><TagsPage /></RequireAuth>} />

        {/* Settings */}
        <Route path="/settings" element={<RequireAuth><SettingsPage /></RequireAuth>} />

        {/* Admin */}
        <Route path="/admin" element={<RequireAuth><RequireAdmin><AdminPage /></RequireAdmin></RequireAuth>} />

        {/* Fallbacks */}
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
