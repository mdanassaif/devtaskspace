'use client';

import { useEffect, useState } from 'react';
import Layout from '@/components/Layout';

type SettingsForm = {
  resendApiKey: string;
  alertEmail: string;
  fromEmail: string;
};

const EMPTY: SettingsForm = {
  resendApiKey: '',
  alertEmail: '',
  fromEmail: '',
};

export default function SettingsPage() {
  const [form, setForm] = useState<SettingsForm>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      try {
        const res = await fetch('/api/settings/integrations', { cache: 'no-store' });
        const data = await res.json();
        if (!res.ok) {
          throw new Error(data?.error || 'Failed to load settings');
        }
        if (active) {
          setForm({
            resendApiKey: '',
            alertEmail: data.settings?.alertEmail || '',
            fromEmail: data.settings?.fromEmail || '',
          });
        }
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : 'Load failed');
      } finally {
        if (active) setLoading(false);
      }
    }
    void load();
    return () => {
      active = false;
    };
  }, []);

  async function save() {
    setSaving(true);
    setMsg('');
    setError('');
    try {
      const res = await fetch('/api/settings/integrations', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data?.error || 'Save failed');
      }
      setMsg('Email settings saved.');
      setForm(f => ({ ...f, resendApiKey: '' }));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Layout title="Settings" subtitle="Email delivery (Resend) without editing env files">
      <div className="card p-5 max-w-2xl border-gray-200">
        {loading ? (
          <p className="text-sm text-gray-500">Loading settings...</p>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="label">Resend API Key</label>
              <input
                className="input"
                type="password"
                placeholder="re_..."
                value={form.resendApiKey}
                onChange={e => setForm(f => ({ ...f, resendApiKey: e.target.value }))}
              />
              <p className="text-[10px] text-gray-400 mt-1">Leave blank to keep existing key.</p>
            </div>

            <div>
              <label className="label">Alert Email (default recipient)</label>
              <input
                className="input"
                placeholder="you@example.com"
                value={form.alertEmail}
                onChange={e => setForm(f => ({ ...f, alertEmail: e.target.value }))}
              />
            </div>

            <div>
              <label className="label">From Email</label>
              <input
                className="input"
                placeholder="Stacker <alerts@yourdomain.com>"
                value={form.fromEmail}
                onChange={e => setForm(f => ({ ...f, fromEmail: e.target.value }))}
              />
            </div>

            {msg && <p className="text-xs text-green-600">{msg}</p>}
            {error && <p className="text-xs text-red-600">{error}</p>}

            <div className="flex justify-end">
              <button className="btn btn-primary btn-lg" onClick={save} disabled={saving}>
                {saving ? 'Saving...' : 'Save Settings'}
              </button>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}

