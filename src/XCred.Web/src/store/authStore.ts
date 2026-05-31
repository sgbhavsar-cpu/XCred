import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface UserInfo {
  id: string;
  username: string;
  email: string;
  fullName: string;
  role: string;
}

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
  user: UserInfo | null;
  publicKey: string | null;        // RSA public key (base64) — persisted, used to encrypt new credentials
  symmetricKey: CryptoKey | null;  // Derived from master password — memory only
  privateKey: CryptoKey | null;    // RSA private key — memory only

  setTokens: (accessToken: string, refreshToken: string) => void;
  setUser: (user: UserInfo) => void;
  setPublicKey: (publicKey: string) => void;
  setCryptoKeys: (symmetricKey: CryptoKey, privateKey: CryptoKey) => void;
  logout: () => void;
  isAuthenticated: () => boolean;
  isAdmin: () => boolean;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      accessToken: null,
      refreshToken: null,
      user: null,
      publicKey: null,
      symmetricKey: null,
      privateKey: null,

      setTokens: (accessToken, refreshToken) => set({ accessToken, refreshToken }),
      setUser: (user) => set({ user }),
      setPublicKey: (publicKey) => set({ publicKey }),
      setCryptoKeys: (symmetricKey, privateKey) => set({ symmetricKey, privateKey }),

      logout: () => set({
        accessToken: null,
        refreshToken: null,
        user: null,
        publicKey: null,
        symmetricKey: null,
        privateKey: null,
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
