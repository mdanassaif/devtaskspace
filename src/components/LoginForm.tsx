'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Lock, ShieldCheck } from 'lucide-react';

type LoginFormProps = {
  redirectTo: string;
};

export default function LoginForm({ redirectTo }: LoginFormProps) {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error || 'Login failed');
        setLoading(false);
        return;
      }
      router.push(redirectTo);
      router.refresh();
    } catch {
      setError('Could not connect to server');
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center px-4 bg-[var(--bg)]">
      <div className="card w-full max-w-sm p-5 border-gray-200">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-lg bg-gray-900 flex items-center justify-center">
            <Lock size={14} className="text-white" />
          </div>
          <div>
            <h1 className="text-lg font-semibold text-gray-900">Sign in</h1>
            <p className="text-[11px] text-gray-500">Self-hosted Stacker workspace</p>
          </div>
        </div>
        <p className="text-xs text-gray-500 mb-4">
          Use the credentials configured in <code className="font-medium text-gray-700">.env.local</code> to continue.
        </p>
        <form onSubmit={onSubmit} className="space-y-3">
          <div>
            <label className="label">Username</label>
            <input
              className="input"
              value={username}
              onChange={e => setUsername(e.target.value)}
              autoComplete="username"
            />
          </div>
          <div>
            <label className="label">Password</label>
            <input
              type="password"
              className="input"
              value={password}
              onChange={e => setPassword(e.target.value)}
              autoComplete="current-password"
            />
          </div>
          {error && <p className="text-xs text-red-600">{error}</p>}
          <button type="submit" className="btn btn-primary btn-lg w-full justify-center" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
        <div className="mt-4 text-[11px] text-gray-500 bg-gray-50 border border-gray-100 rounded-md px-3 py-2 flex items-start gap-2">
          <ShieldCheck size={13} className="text-gray-400 mt-0.5 shrink-0" />
          <span>Credentials are verified server-side and the session cookie is signed, HTTP-only, and expiry-aware.</span>
        </div>
      </div>
    </main>
  );
}
