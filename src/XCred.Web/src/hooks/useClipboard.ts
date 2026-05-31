import { useCallback, useEffect, useRef, useState } from 'react';
import { useAuthStore } from '@/store/authStore';
import api from '@/api/client';
import toast from 'react-hot-toast';

export function useClipboard(credentialId?: string) {
  const [copied, setCopied] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const clearTimers = () => {
    if (timerRef.current) clearInterval(timerRef.current);
  };

  useEffect(() => () => clearTimers(), []);

  const copyToClipboard = useCallback(async (value: string, fieldName = 'password') => {
    await navigator.clipboard.writeText(value);
    setCopied(true);

    // Log copy action
    if (credentialId) {
      api.post(`/credentials/${credentialId}/copy`, null, { params: { field: fieldName } }).catch(() => {});
    }

    const orgSettings = useAuthStore.getState();
    // Default 30s if settings not loaded yet
    const clearAfter = 30;
    setCountdown(clearAfter);

    clearTimers();
    timerRef.current = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearTimers();
          navigator.clipboard.writeText('').catch(() => {});
          setCopied(false);
          toast('Clipboard cleared.', { icon: '🔒', duration: 2000 });
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }, [credentialId]);

  return { copied, countdown, copyToClipboard };
}
