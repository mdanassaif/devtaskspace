'use client';

import { useState } from 'react';
import Layout from '@/components/Layout';
import Modal from '@/components/Modal';
import { useSyncedCollection } from '@/hooks/useSyncedCollection';
import { Subscription } from '@/lib/types';
import { generateId, formatDate, daysUntil, cycleLabel, cn } from '@/lib/utils';
import { Plus, CreditCard, Trash2, Edit2, Mail, ToggleLeft, ToggleRight } from 'lucide-react';

const EMPTY: Omit<Subscription, 'id' | 'createdAt'> = {
  name: '',
  website: '',
  price: 0,
  currency: 'USD',
  billingCycle: 'monthly',
  nextBillingDate: '',
  category: 'tool',
  notes: '',
  isActive: true,
};

const CATEGORY_COLORS: Record<string, string> = {
  tool: 'bg-blue-50 text-blue-600 border-blue-100',
  hosting: 'bg-purple-50 text-purple-600 border-purple-100',
  saas: 'bg-indigo-50 text-indigo-600 border-indigo-100',
  design: 'bg-pink-50 text-pink-600 border-pink-100',
  ai: 'bg-amber-50 text-amber-600 border-amber-100',
  other: 'bg-gray-50 text-gray-600 border-gray-100',
};

export default function SubscriptionsPage() {
  const [subs, setSubs, sync] = useSyncedCollection<Subscription[]>('subscriptions', 'subscriptions', []);
  const [showModal, setShowModal] = useState(false);
  const [editSub, setEditSub] = useState<Subscription | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [catFilter, setCatFilter] = useState('all');
  const [emailMsg, setEmailMsg] = useState('');

  function openAdd() { setEditSub(null); setForm(EMPTY); setShowModal(true); }
  function openEdit(s: Subscription) {
    setEditSub(s);
    setForm({ name: s.name, website: s.website || '', price: s.price, currency: s.currency, billingCycle: s.billingCycle, nextBillingDate: s.nextBillingDate, category: s.category, notes: s.notes || '', isActive: s.isActive });
    setShowModal(true);
  }

  function save() {
    if (!form.name.trim()) return;
    if (editSub) {
      setSubs(prev => prev.map(s => s.id === editSub.id ? { ...editSub, ...form } : s));
    } else {
      setSubs(prev => [{ ...form, id: generateId(), createdAt: new Date().toISOString() }, ...prev]);
    }
    setShowModal(false);
  }

  function deleteSub(id: string) { setSubs(prev => prev.filter(s => s.id !== id)); }
  function toggleActive(id: string) { setSubs(prev => prev.map(s => s.id === id ? { ...s, isActive: !s.isActive } : s)); }

  async function sendBillingAlert() {
    const dueSoon = subs.filter(s => s.isActive && daysUntil(s.nextBillingDate) <= 7);
    if (!dueSoon.length) { setEmailMsg('No bills due in 7 days.'); return; }
    try {
      const res = await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subject: '💳 Upcoming Billing Alert',
          text: dueSoon.map(s => `${s.name} — $${s.price} on ${formatDate(s.nextBillingDate)}`).join('\n'),
        }),
      });
      const data = await res.json();
      setEmailMsg(data.success ? `Alert sent for ${dueSoon.length} subscription(s)!` : 'Failed');
    } catch { setEmailMsg('Error'); }
    setTimeout(() => setEmailMsg(''), 4000);
  }

  const active = subs.filter(s => s.isActive);
  const monthly = active.filter(s => s.billingCycle === 'monthly').reduce((sum, s) => sum + s.price, 0);
  const yearly = active.filter(s => s.billingCycle === 'yearly').reduce((sum, s) => sum + s.price / 12, 0);
  const totalMonthly = monthly + yearly;

  const filtered = subs.filter(s => catFilter === 'all' || s.category === catFilter);
  const dueSoon = subs.filter(s => s.isActive && daysUntil(s.nextBillingDate) <= 7).length;

  return (
    <Layout
      title="Subscriptions"
      subtitle={`${active.length} active · $${totalMonthly.toFixed(2)}/mo total${sync.syncing ? ' · syncing...' : ''}`}
      action={
        <div className="flex items-center gap-2">
          {emailMsg && <span className="text-[11px] text-green-600">{emailMsg}</span>}
          <button className="btn btn-default btn-lg" onClick={sendBillingAlert}><Mail size={13} /> Alert Due</button>
          <button className="btn btn-primary btn-lg" onClick={openAdd}><Plus size={13} /> Add Subscription</button>
        </div>
      }
    >
      {sync.error && (
        <div className="mb-4 text-xs text-amber-700 bg-amber-50 border border-amber-100 rounded-md px-3 py-2">
          Cloud sync issue: {sync.error}
        </div>
      )}
      {/* Stats */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className="card p-4">
          <p className="text-2xl font-semibold text-gray-900">${totalMonthly.toFixed(0)}</p>
          <p className="text-xs text-gray-500 mt-1">Monthly Cost</p>
        </div>
        <div className="card p-4">
          <p className="text-2xl font-semibold text-gray-900">${(totalMonthly * 12).toFixed(0)}</p>
          <p className="text-xs text-gray-500 mt-1">Yearly Cost</p>
        </div>
        <div className="card p-4">
          <p className="text-2xl font-semibold text-gray-900">{active.length}</p>
          <p className="text-xs text-gray-500 mt-1">Active Tools</p>
        </div>
        <div className={cn('card p-4', dueSoon > 0 && 'border-amber-100 bg-amber-50/20')}>
          <p className={cn('text-2xl font-semibold', dueSoon > 0 ? 'text-amber-600' : 'text-gray-900')}>{dueSoon}</p>
          <p className="text-xs text-gray-500 mt-1">Due in 7 days</p>
        </div>
      </div>

      {/* Filter */}
      <div className="flex items-center gap-2 mb-4">
        {['all', 'tool', 'hosting', 'saas', 'design', 'ai', 'other'].map(c => (
          <button
            key={c}
            onClick={() => setCatFilter(c)}
            className={cn('btn btn-sm', catFilter === c ? 'btn-primary' : 'btn-default')}
          >
            {c.charAt(0).toUpperCase() + c.slice(1)}
          </button>
        ))}
      </div>

      {/* List */}
      {filtered.length === 0 ? (
        <div className="text-center py-16">
          <CreditCard size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">No subscriptions tracked.</p>
          <button className="btn btn-primary mt-4" onClick={openAdd}><Plus size={12} /> Add first</button>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-100">
                {['Tool', 'Category', 'Price', 'Billing', 'Next Due', 'Status', ''].map(h => (
                  <th key={h} className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map(sub => {
                const days = daysUntil(sub.nextBillingDate);
                const urgency = sub.isActive && days <= 3 ? 'text-red-500' : sub.isActive && days <= 7 ? 'text-amber-500' : 'text-gray-400';
                return (
                  <tr key={sub.id} className={cn('table-row hover:bg-gray-50/50 group', !sub.isActive && 'opacity-50')}>
                    <td className="px-4 py-3">
                      <p className="text-xs font-medium text-gray-800">{sub.name}</p>
                      {sub.website && <a href={sub.website} target="_blank" rel="noopener noreferrer" className="text-[10px] text-blue-400 hover:underline">{sub.website}</a>}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`badge border ${CATEGORY_COLORS[sub.category]}`}>{sub.category}</span>
                    </td>
                    <td className="px-4 py-3">
                      <span className="text-xs font-semibold text-gray-800">${sub.price}</span>
                      <span className="text-[10px] text-gray-400">{cycleLabel(sub.billingCycle)}</span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500 capitalize">{sub.billingCycle}</td>
                    <td className={`px-4 py-3 text-xs ${urgency}`}>
                      {sub.nextBillingDate ? formatDate(sub.nextBillingDate) : '—'}
                      {sub.isActive && days <= 7 && days >= 0 && <span className="ml-1 text-[10px]">({days}d)</span>}
                    </td>
                    <td className="px-4 py-3">
                      <button onClick={() => toggleActive(sub.id)} className="text-gray-400 hover:text-gray-600">
                        {sub.isActive
                          ? <ToggleRight size={18} className="text-green-500" />
                          : <ToggleLeft size={18} />
                        }
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex gap-1 opacity-0 group-hover:opacity-100">
                        <button className="btn btn-sm btn-default" onClick={() => openEdit(sub)}><Edit2 size={10} /></button>
                        <button className="btn btn-sm btn-danger" onClick={() => deleteSub(sub.id)}><Trash2 size={10} /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <Modal open={showModal} onClose={() => setShowModal(false)} title={editSub ? 'Edit Subscription' : 'Add Subscription'}>
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2">
              <label className="label">Tool / Service *</label>
              <input className="input" placeholder="e.g. Vercel, Figma..." value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="col-span-2">
              <label className="label">Website</label>
              <input className="input" placeholder="https://..." value={form.website} onChange={e => setForm(f => ({ ...f, website: e.target.value }))} />
            </div>
            <div>
              <label className="label">Price</label>
              <input type="number" className="input" placeholder="0.00" value={form.price || ''} onChange={e => setForm(f => ({ ...f, price: parseFloat(e.target.value) || 0 }))} />
            </div>
            <div>
              <label className="label">Billing Cycle</label>
              <select className="input" value={form.billingCycle} onChange={e => setForm(f => ({ ...f, billingCycle: e.target.value as Subscription['billingCycle'] }))}>
                <option value="monthly">Monthly</option>
                <option value="yearly">Yearly</option>
                <option value="weekly">Weekly</option>
                <option value="one-time">One-time</option>
              </select>
            </div>
            <div>
              <label className="label">Category</label>
              <select className="input" value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value as Subscription['category'] }))}>
                <option value="tool">Tool</option>
                <option value="hosting">Hosting</option>
                <option value="saas">SaaS</option>
                <option value="design">Design</option>
                <option value="ai">AI</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label className="label">Next Billing Date</label>
              <input type="date" className="input" value={form.nextBillingDate} onChange={e => setForm(f => ({ ...f, nextBillingDate: e.target.value }))} />
            </div>
            <div className="col-span-2">
              <label className="label">Notes</label>
              <input className="input" placeholder="Plan, notes..." value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} />
            </div>
          </div>
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" checked={form.isActive} onChange={e => setForm(f => ({ ...f, isActive: e.target.checked }))} className="rounded border-gray-300" />
            <span className="text-xs text-gray-600">Currently active</span>
          </label>
          <div className="flex justify-end gap-2 pt-2">
            <button className="btn btn-default btn-lg" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn btn-primary btn-lg" onClick={save}>{editSub ? 'Save changes' : 'Add subscription'}</button>
          </div>
        </div>
      </Modal>
    </Layout>
  );
}
