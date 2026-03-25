'use client';

import { useState } from 'react';
import Layout from '@/components/Layout';
import Modal from '@/components/Modal';
import { useLocalStorage } from '@/hooks/useLocalStorage';
import { PlanningItem } from '@/lib/types';
import { generateId, formatDate, priorityColor, cn } from '@/lib/utils';
import { Plus, Calendar, Trash2, Edit2, CheckCircle2, Circle, Clock, FileText, Code2, BookOpen, Users, Pin } from 'lucide-react';

const TYPE_ICONS: Record<string, React.ElementType> = {
  blog: FileText,
  meeting: Users,
  coding: Code2,
  reading: BookOpen,
  other: Pin,
};

const TYPE_COLORS: Record<string, string> = {
  blog: 'bg-purple-50 text-purple-600 border-purple-100',
  meeting: 'bg-blue-50 text-blue-600 border-blue-100',
  coding: 'bg-green-50 text-green-600 border-green-100',
  reading: 'bg-amber-50 text-amber-600 border-amber-100',
  other: 'bg-gray-50 text-gray-600 border-gray-100',
};

const PLAN_STATUS = ['idea', 'planned', 'in-progress', 'done'] as const;

const EMPTY: Omit<PlanningItem, 'id' | 'createdAt'> = {
  type: 'coding',
  title: '',
  description: '',
  status: 'idea',
  scheduledDate: '',
  priority: 'medium',
  notes: '',
};

export default function PlanningPage() {
  const [items, setItems] = useLocalStorage<PlanningItem[]>('planning', []);
  const [showModal, setShowModal] = useState(false);
  const [editItem, setEditItem] = useState<PlanningItem | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [activeType, setActiveType] = useState<string>('all');
  const [activeStatus, setActiveStatus] = useState<string>('all');

  function openAdd(type?: string) {
    setEditItem(null);
    setForm({ ...EMPTY, type: (type as PlanningItem['type']) || 'coding' });
    setShowModal(true);
  }

  function openEdit(item: PlanningItem) {
    setEditItem(item);
    setForm({ type: item.type, title: item.title, description: item.description || '', status: item.status, scheduledDate: item.scheduledDate || '', priority: item.priority, notes: item.notes || '' });
    setShowModal(true);
  }

  function save() {
    if (!form.title.trim()) return;
    if (editItem) {
      setItems(prev => prev.map(i => i.id === editItem.id ? { ...editItem, ...form } : i));
    } else {
      setItems(prev => [{ ...form, id: generateId(), createdAt: new Date().toISOString() }, ...prev]);
    }
    setShowModal(false);
  }

  function deleteItem(id: string) { setItems(prev => prev.filter(i => i.id !== id)); }
  function cycleStatus(item: PlanningItem) {
    const statusOrder: PlanningItem['status'][] = ['idea', 'planned', 'in-progress', 'done'];
    const next = statusOrder[(statusOrder.indexOf(item.status) + 1) % statusOrder.length];
    setItems(prev => prev.map(i => i.id === item.id ? { ...i, status: next } : i));
  }

  const filtered = items
    .filter(i => activeType === 'all' || i.type === activeType)
    .filter(i => activeStatus === 'all' || i.status === activeStatus);

  const types = ['blog', 'meeting', 'coding', 'reading', 'other'];
  const typeCounts = types.reduce((acc, t) => ({ ...acc, [t]: items.filter(i => i.type === t).length }), {} as Record<string, number>);

  return (
    <Layout
      title="Planning"
      subtitle={`${items.filter(i => i.status !== 'done').length} active · ${items.filter(i => i.status === 'done').length} done`}
      action={
        <button className="btn btn-primary btn-lg" onClick={() => openAdd()}>
          <Plus size={13} /> Add Item
        </button>
      }
    >
      {/* Type tabs */}
      <div className="grid grid-cols-6 gap-3 mb-5">
        <div
          onClick={() => setActiveType('all')}
          className={cn('card p-3 cursor-pointer text-center hover:border-gray-200', activeType === 'all' && 'ring-1 ring-gray-900 border-gray-300')}
        >
          <p className="text-lg font-semibold text-gray-900">{items.length}</p>
          <p className="text-[10px] text-gray-500 mt-0.5">All</p>
        </div>
        {types.map(t => {
          const Icon = TYPE_ICONS[t];
          return (
            <div
              key={t}
              onClick={() => setActiveType(t === activeType ? 'all' : t)}
              className={cn('card p-3 cursor-pointer hover:border-gray-200', activeType === t && 'ring-1 ring-gray-900 border-gray-300')}
            >
              <div className="flex items-center gap-1.5 mb-1">
                <Icon size={12} className="text-gray-400" />
                <p className="text-base font-semibold text-gray-900">{typeCounts[t] || 0}</p>
              </div>
              <p className="text-[10px] text-gray-500 capitalize">{t}</p>
            </div>
          );
        })}
      </div>

      {/* Status filter */}
      <div className="flex items-center gap-1.5 mb-4">
        {['all', ...PLAN_STATUS].map(s => (
          <button
            key={s}
            onClick={() => setActiveStatus(s)}
            className={cn('btn btn-sm capitalize', activeStatus === s ? 'btn-primary' : 'btn-default')}
          >
            {s === 'in-progress' ? 'In Progress' : s}
          </button>
        ))}
      </div>

      {/* Items */}
      {filtered.length === 0 ? (
        <div className="text-center py-16">
          <Calendar size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">Nothing planned yet.</p>
          <button className="btn btn-primary mt-4" onClick={() => openAdd()}><Plus size={12} /> Add item</button>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map(item => {
            const Icon = TYPE_ICONS[item.type];
            return (
              <div
                key={item.id}
                className={cn('card px-4 py-3 flex items-start gap-3 group', item.status === 'done' && 'opacity-60')}
              >
                <button
                  onClick={() => cycleStatus(item)}
                  className="mt-0.5 shrink-0 text-gray-300 hover:text-gray-600"
                  title={`Status: ${item.status}`}
                >
                  {item.status === 'done'
                    ? <CheckCircle2 size={15} className="text-green-500" />
                    : item.status === 'in-progress'
                    ? <Clock size={15} className="text-blue-400" />
                    : item.status === 'planned'
                    ? <Circle size={15} className="text-amber-300" />
                    : <Circle size={15} />
                  }
                </button>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className={cn('text-sm font-medium text-gray-800', item.status === 'done' && 'line-through text-gray-400')}>
                      {item.title}
                    </p>
                    <span className={`badge border ${TYPE_COLORS[item.type]}`}>
                      <Icon size={8} className="mr-0.5" />
                      {item.type}
                    </span>
                    <span className={`badge border ${priorityColor(item.priority)}`}>{item.priority}</span>
                    <span className={cn('badge border', item.status === 'done' ? 'bg-green-50 text-green-600 border-green-100' : item.status === 'in-progress' ? 'bg-blue-50 text-blue-600 border-blue-100' : item.status === 'planned' ? 'bg-amber-50 text-amber-600 border-amber-100' : 'bg-gray-50 text-gray-500 border-gray-100')}>
                      {item.status}
                    </span>
                  </div>
                  {item.description && <p className="text-[11px] text-gray-400 mt-1 line-clamp-1">{item.description}</p>}
                  <div className="flex gap-3 mt-1.5">
                    {item.scheduledDate && <span className="text-[10px] text-gray-400">📅 {formatDate(item.scheduledDate)}</span>}
                    {item.notes && <span className="text-[10px] text-gray-400 line-clamp-1">📝 {item.notes}</span>}
                  </div>
                </div>

                <div className="flex gap-1 opacity-0 group-hover:opacity-100 shrink-0">
                  <button className="btn btn-sm btn-default" onClick={() => openEdit(item)}><Edit2 size={10} /></button>
                  <button className="btn btn-sm btn-danger" onClick={() => deleteItem(item.id)}><Trash2 size={10} /></button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <Modal open={showModal} onClose={() => setShowModal(false)} title={editItem ? 'Edit Item' : 'Plan Something'}>
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Type</label>
              <select className="input" value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value as PlanningItem['type'] }))}>
                <option value="coding">💻 Coding</option>
                <option value="blog">✍️ Blog</option>
                <option value="meeting">📅 Meeting</option>
                <option value="reading">📚 Reading</option>
                <option value="other">📌 Other</option>
              </select>
            </div>
            <div>
              <label className="label">Priority</label>
              <select className="input" value={form.priority} onChange={e => setForm(f => ({ ...f, priority: e.target.value as PlanningItem['priority'] }))}>
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
              </select>
            </div>
            <div className="col-span-2">
              <label className="label">Title *</label>
              <input className="input" placeholder="What are you planning?" value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
            </div>
            <div className="col-span-2">
              <label className="label">Description</label>
              <textarea className="input resize-none" rows={2} value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
            </div>
            <div>
              <label className="label">Status</label>
              <select className="input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as PlanningItem['status'] }))}>
                <option value="idea">💡 Idea</option>
                <option value="planned">📋 Planned</option>
                <option value="in-progress">⚡ In Progress</option>
                <option value="done">✅ Done</option>
              </select>
            </div>
            <div>
              <label className="label">Scheduled Date</label>
              <input type="date" className="input" value={form.scheduledDate} onChange={e => setForm(f => ({ ...f, scheduledDate: e.target.value }))} />
            </div>
            <div className="col-span-2">
              <label className="label">Notes</label>
              <textarea className="input resize-none" rows={2} placeholder="Resources, links, context..." value={form.notes} onChange={e => setForm(f => ({ ...f, notes: e.target.value }))} />
            </div>
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button className="btn btn-default btn-lg" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn btn-primary btn-lg" onClick={save}>{editItem ? 'Save' : 'Add item'}</button>
          </div>
        </div>
      </Modal>
    </Layout>
  );
}
