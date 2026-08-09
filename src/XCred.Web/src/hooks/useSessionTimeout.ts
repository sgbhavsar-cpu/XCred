import { useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore, DEFAULT_ORG_SETTINGS } from '@/store/authStore';
import api from '@/api/client';

export function useSessionTimeout() {
  const navigate = useNavigate();
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const { isAuthenticated, logout, refreshToken, orgSettings } = useAuthStore();
  const timeoutMinutes = orgSettings?.sessionTimeoutMinutes ?? DEFAULT_ORG_SETTINGS.sessionTimeoutMinutes;

  const resetTimer = useCallback(() => {
    if (timerRef.current) clearTimeout(timerRef.current);
    if (!isAuthenticated()) return;

    timerRef.current = setTimeout(async () => {
      if (refreshToken) {
        try { await api.post('/auth/logout', { refreshToken }); } catch {}
      }
      logout();
      navigate('/login?reason=session_expired');
    }, timeoutMinutes * 60 * 1000);
  }, [isAuthenticated, logout, navigate, refreshToken, timeoutMinutes]);

  useEffect(() => {
    const events = ['mousedown', 'keydown', 'scroll', 'touchstart'];
    events.forEach(e => window.addEventListener(e, resetTimer));
    resetTimer();
    return () => {
      events.forEach(e => window.removeEventListener(e, resetTimer));
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [resetTimer]);
}
