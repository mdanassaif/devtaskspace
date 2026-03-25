'use client';

import { useState } from 'react';
import Layout from '@/components/Layout';
import Modal from '@/components/Modal';
import { useSyncedCollection } from '@/hooks/useSyncedCollection';
import { Domain } from '@/lib/types';
import { generateId, formatDate, daysUntil, cn } from '@/lib/utils';
import { Plus, Globe, RefreshCw, Trash2, Edit2, Mail } from 'lucide-react';

const EMPTY: Omit<Domain, 'id' | 'createdAt'> = {
  name: '',
  registrar: '',
  expiryDate: '',
  autoRenew: false,
  notes: '',
  cost: undefined,
};

function ExpiryBadge({ days }: { days: number }) {
  if (days < 0) return <span className="badge border bg-red-50 text-red-600 border-red-100">Expired</span>;
  if (days <= 14) return <span className="badge border bg-red-50 text-red-600 border-red-100">⚠ {days}d left</span>;
  if (days <= 45) return <span className="badge border bg-amber-50 text-amber-600 border-amber-100">{days}d left</span>;
  return <span className="badge border bg-green-50 text-green-600 border-green-100">{days}d left</span>;
}

export default function DomainsPage() {
  const [domains, setDomains, sync] = useSyncedCollection<Domain[]>('domains', 'domains', []);
  const [showModal, setShowModal] = useState(false);
  const [editDomain, setEditDomain] = useState<Domain | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [emailStatus, setEmailStatus] = useState<string>('');

  function openAdd() {
    setEditDomain(null);
    setForm(EMPTY);
    setShowModal(true);
  }

  function openEdit(domain: Domain) {
    setEditDomain(domain);
    setForm({
      name: domain.name,
      registrar: domain.registrar,
      expiryDate: domain.expiryDate,
      autoRenew: domain.autoRenew,
      notes: domain.notes || '',
      cost: domain.cost,
    });
    setShowModal(true);
  }

  function save() {
    if (!form.name.trim() || !form.expiryDate) return;
    if (editDomain) {
      setDomains(prev => prev.map(d => d.id === editDomain.id ? { ...editDomain, ...form } : d));
    } else {
      setDomains(prev => [{ ...form, id: generateId(), createdAt: new Date().toISOString() }, ...prev]);
    }
    setShowModal(false);
  }

  function deleteDomain(id: string) {
    setDomains(prev => prev.filter(d => d.id !== id));
  }

  async function sendExpiryAlert() {
    const expiringSoon = domains.filter(d => daysUntil(d.expiryDate) <= 30);
    if (expiringSoon.length === 0) { setEmailStatus('No domains expiring within 30 days.'); return; }
    try {
      const res = await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subject: '🌐 Domain Expiry Alert',
          text: expiringSoon.map(d => `${d.name} — expires ${formatDate(d.expiryDate)} (${daysUntil(d.expiryDate)}d)`).join('\n'),
        }),
      });
      const data = await res.json();
      setEmailStatus(data.success ? `Alert sent for ${expiringSoon.length} domain(s)!` : 'Failed to send');
    } catch { setEmailStatus('Email error'); }
    setTimeout(() => setEmailStatus(''), 4000);
  }

  const sorted = [...domains].sort((a, b) => daysUntil(a.expiryDate) - daysUntil(b.expiryDate));
  const critical = sorted.filter(d => daysUntil(d.expiryDate) <= 30).length;
  const totalCost = domains.reduce((sum, d) => sum + (d.cost || 0), 0);

  return (
    <Layout
      title="Domains"
      subtitle={`${domains.length} domains · ${critical > 0 ? `${critical} expiring soon` : 'All healthy'}${sync.syncing ? ' · syncing...' : ''}`}
      action={
        <div className="flex items-center gap-2">
          {emailStatus && <span className="text-[11px] text-green-600">{emailStatus}</span>}
          <button className="btn btn-default btn-lg" onClick={sendExpiryAlert}>
            <Mail size={13} /> Alert Expiring
          </button>
          <button className="btn btn-primary btn-lg" onClick={openAdd}>
            <Plus size={13} /> Add Domain
          </button>
        </div>
      }
    >
      {sync.error && (
        <div className="mb-4 text-xs text-amber-700 bg-amber-50 border border-amber-100 rounded-md px-3 py-2">
          Cloud sync issue: {sync.error}
        </div>
      )}
      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="card p-4 text-center">
          <p className="text-2xl font-semibold text-gray-900">{domains.length}</p>
          <p className="text-xs text-gray-500 mt-1">Total Domains</p>
        </div>
        <div className={cn('card p-4 text-center', critical > 0 && 'border-red-100 bg-red-50/20')}>
          <p className={cn('text-2xl font-semibold', critical > 0 ? 'text-red-600' : 'text-gray-900')}>{critical}</p>
          <p className="text-xs text-gray-500 mt-1">Expiring ≤30d</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-2xl font-semibold text-gray-900">${totalCost.toFixed(0)}</p>
          <p className="text-xs text-gray-500 mt-1">Annual Cost</p>
        </div>
      </div>

      {/* Domain list */}
      {sorted.length === 0 ? (
        <div className="text-center py-16">
          <Globe size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">No domains yet.</p>
          <button className="btn btn-primary mt-4" onClick={openAdd}><Plus size={12} /> Add domain</button>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">Domain</th>
                <th className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">Registrar</th>
                <th className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">Expiry</th>
                <th className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">Status</th>
                <th className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">Cost/yr</th>
                <th className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">Auto-renew</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map(domain => {
                const days = daysUntil(domain.expiryDate);
                return (
                  <tr key={domain.id} className="table-row hover:bg-gray-50/50 group">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <Globe size={13} className="text-gray-400 shrink-0" />
                        <span className="font-medium text-gray-800 text-xs">{domain.name}</span>
                      </div>
                      {domain.notes && <p className="text-[10px] text-gray-400 mt-0.5 ml-5">{domain.notes}</p>}
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">{domain.registrar || '—'}</td>
                    <td className="px-4 py-3 text-xs text-gray-600">{formatDate(domain.expiryDate)}</td>
                    <td className="px-4 py-3"><ExpiryBadge days={days} /></td>
                    <td className="px-4 py-3 text-xs text-gray-500">{domain.cost ? `$${domain.cost}` : '—'}</td>
                    <td className="px-4 py-3">
                      {domain.autoRenew
                        ? <span className="badge border bg-green-50 text-green-600 border-green-100"><RefreshCw size={8} className="mr-0.5" /> On</span>
                        : <span className="badge border bg-gray-50 text-gray-400 border-gray-100">Off</span>
                      }
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100">
                        <button className="btn btn-sm btn-default" onClick={() => openEdit(domain)}><Edit2 size={10} /></button>
                        <button className="btn btn-sm btn-danger" onClick={() => deleteDomain(domain.id)}><Trash2 size={10} /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <Modal open={showModal} onClose={() => setShowModal(false)} title={editDomain ? 'Edit Domain' : 'Add Domain'}>
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2">
              <label className="label">Domain name *</label>
              <input className="input" placeholder="example.com" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div>
              <label className="label">Registrar</label>
              <input className="input" placeholder="Namecheap, GoDaddy..." value={form.registrar} onChange={e => setForm(f => ({ ...f, registrar: e.target.value }))} />
            </div>
            <div>
              <label className="label">Cost per year ($)</label>
              <input type="number" className="input" placeholder="12" value={form.cost || ''} onChange={e => setForm(f => ({ ...f, cost: parseFloat(e.target.value) || undefined }))} />
            </div>
            <div className="col-span-2">
              <label className="label">Expiry Date *</label>
              <input type="date" className="input" value={form.expiryDate} onChange={e => setForm(f => ({ ...f, expiryDate: e.target.value }))} />
            </div>
            <div className="col-span-2">
              <label className="label">Notes</label>
              <input className="input" placeholder="Any notes..." value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} />
            </div>
          </div>
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" checked={form.autoRenew} onChange={e => setForm(f => ({ ...f, autoRenew: e.target.checked }))} className="rounded border-gray-300" />
            <span className="text-xs text-gray-600">Auto-renew enabled</span>
          </label>
          <div className="flex justify-end gap-2 pt-2">
            <button className="btn btn-default btn-lg" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn btn-primary btn-lg" onClick={save}>{editDomain ? 'Save changes' : 'Add domain'}</button>
          </div>
        </div>
      </Modal>
    </Layout>
  );
}
