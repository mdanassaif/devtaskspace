'use client';

import { useState } from 'react';
import { LogOut } from 'lucide-react';

export default function LogoutButton() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function logout() {
    if (loading) return;
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/auth/logout', {
        method: 'POST',
        credentials: 'include',
        cache: 'no-store',
      });
      if (!res.ok) {
        throw new Error('Logout request failed');
      }
    } catch {
      setError('Logout failed. Retry.');
      setLoading(false);
      return;
    }
    window.location.replace('/login');
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <button className="btn btn-default btn-sm" onClick={logout} disabled={loading}>
        <LogOut size={15} />
        {loading ? 'Logging out...' : 'Logout'}
      </button>
      {error ? <span className="text-[10px] text-red-600">{error}</span> : null}
    </div>
  );
}

