import { useCallback, useEffect, useRef, useState } from 'react';

type SyncResource = 'tasks' | 'domains' | 'subscriptions';

export function useSyncedCollection<T>(
  resource: SyncResource,
  localKey: string,
  initialValue: T
) {
  const initialValueRef = useRef(initialValue);
  const [value, setValue] = useState<T>(initialValueRef.current);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [error, setError] = useState('');
  const canSyncRef = useRef(false);

  useEffect(() => {
    let active = true;

    async function load() {
      setLoading(true);
      setError('');

      try {
        const local = window.localStorage.getItem(localKey);
        if (local && active) {
          setValue(JSON.parse(local));
        }
      } catch (err) {
        console.warn('Local read failed:', err);
      }

      try {
        const res = await fetch(`/api/sync/${resource}`, {
          method: 'GET',
          credentials: 'include',
          cache: 'no-store',
        });
        if (!res.ok) {
          if (res.status === 401) {
            canSyncRef.current = false;
          }
          throw new Error(`Sync load failed (${res.status})`);
        }
        const data = await res.json();
        const remoteItems = (data?.items ?? initialValueRef.current) as T;
        if (active) {
          setValue(remoteItems);
          window.localStorage.setItem(localKey, JSON.stringify(remoteItems));
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unable to load cloud data';
        if (active) setError(message);
      } finally {
        if (active) {
          canSyncRef.current = true;
          setLoading(false);
        }
      }
    }

    void load();

    return () => {
      active = false;
    };
  }, [resource, localKey]);

  const persist = useCallback(
    async (nextValue: T) => {
      if (!canSyncRef.current) return;
      setSyncing(true);
      setError('');
      try {
        const res = await fetch(`/api/sync/${resource}`, {
          method: 'PUT',
          credentials: 'include',
          cache: 'no-store',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ items: nextValue }),
        });
        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          throw new Error(data?.error || `Sync write failed (${res.status})`);
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unable to save cloud data';
        setError(message);
      } finally {
        setSyncing(false);
      }
    },
    [resource]
  );

  const setSyncedValue = useCallback(
    (next: T | ((prev: T) => T)) => {
      setValue(prev => {
        const nextValue = next instanceof Function ? next(prev) : next;
        window.localStorage.setItem(localKey, JSON.stringify(nextValue));
        void persist(nextValue);
        return nextValue;
      });
    },
    [localKey, persist]
  );

  return [value, setSyncedValue, { loading, syncing, error }] as const;
}

