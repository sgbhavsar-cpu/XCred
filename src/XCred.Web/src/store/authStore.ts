import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface UserInfo {
  id: string;
  username: string;
  email: string;
  fullName: string;
  role: string;
}

interface OrgSettings {
  clipboardClearSeconds: number;
  expiryWarningDays: number;
  sessionTimeoutMinutes: number;
  maxAttachmentSizeMb: number;
}

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
  user: UserInfo | null;
  publicKey: string | null;        // RSA public key (base64) — persisted, used to encrypt new credentials
  symmetricKey: CryptoKey | null;  // Derived from master password — memory only
  privateKey: CryptoKey | null;    // RSA private key — memory only
  orgSettings: OrgSettings | null; // Admin-configurable org settings, fetched from /dashboard — memory only

  setTokens: (accessToken: string, refreshToken: string) => void;
  setUser: (user: UserInfo) => void;
  setPublicKey: (publicKey: string) => void;
  setCryptoKeys: (symmetricKey: CryptoKey, privateKey: CryptoKey) => void;
  setOrgSettings: (orgSettings: OrgSettings) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
  isAdmin: () => boolean;
}

// Fallback defaults — used only until /dashboard has loaded orgSettings for the session,
// or if that fetch fails. Match the server's own defaults (AppSettingKeys seed data).
export const DEFAULT_ORG_SETTINGS: OrgSettings = {
  clipboardClearSeconds: 30,
  expiryWarningDays: 30,
  sessionTimeoutMinutes: 15,
  maxAttachmentSizeMb: 10,
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      accessToken: null,
      refreshToken: null,
      user: null,
      publicKey: null,
      symmetricKey: null,
      privateKey: null,
      orgSettings: null,

      setTokens: (accessToken, refreshToken) => set({ accessToken, refreshToken }),
      setUser: (user) => set({ user }),
      setPublicKey: (publicKey) => set({ publicKey }),
      setCryptoKeys: (symmetricKey, privateKey) => set({ symmetricKey, privateKey }),
      setOrgSettings: (orgSettings) => set({ orgSettings }),

      logout: () => set({
        accessToken: null,
        refreshToken: null,
        user: null,
        publicKey: null,
        symmetricKey: null,
        privateKey: null,
        orgSettings: null,
      }),

      isAuthenticated: () => {
        const { accessToken, privateKey } = get();
        return !!accessToken && !!privateKey;
      },

      isAdmin: () => get().user?.role === 'Admin',
    }),
    {
      name: 'xcred-auth',
      // Persist tokens, user info, and public key; never persist crypto keys
      partialize: (state) => ({
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
        user: state.user,
        publicKey: state.publicKey,
      }),
    }
  )
);
