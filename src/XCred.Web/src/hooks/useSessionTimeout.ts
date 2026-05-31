import { useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/store/authStore';
import api from '@/api/client';

const TIMEOUT_MINUTES = 15;

export function useSessionTimeout() {
  const navigate = useNavigate();
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const { isAuthenticated, logout, refreshToken } = useAuthStore();

  const resetTimer = useCallback(() => {
    if (timerRef.current) clearTimeout(timerRef.current);
    if (!isAuthenticated()) return;

    timerRef.current = setTimeout(async () => {
      if (refreshToken) {
        try { await api.post('/auth/logout', { refreshToken }); } catch {}
      }
      logout();
      navigate('/login?reason=session_expired');
    }, TIMEOUT_MINUTES * 60 * 1000);
  }, [isAuthenticated, logout, navigate, refreshToken]);

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
