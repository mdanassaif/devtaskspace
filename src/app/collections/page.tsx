'use client';

import { useState } from 'react';
import Layout from '@/components/Layout';
import Modal from '@/components/Modal';
import { useLocalStorage } from '@/hooks/useLocalStorage';
import { Collection, CollectionItem } from '@/lib/types';
import { generateId, formatDate, cn } from '@/lib/utils';
import { Plus, BookMarked, Trash2, Edit2, ExternalLink, ChevronDown, ChevronRight, Palette } from 'lucide-react';

const COLORS = [
  '#E8F4FD', '#FEF3C7', '#D1FAE5', '#FCE7F3', '#EDE9FE',
  '#FEE2E2', '#F3F4F6', '#ECFDF5', '#FFF7ED', '#F0F9FF',
];

const EMPTY_COLLECTION = { name: '', description: '', color: COLORS[0] };
const EMPTY_ITEM = { title: '', url: '', notes: '' };

export default function CollectionsPage() {
  const [collections, setCollections] = useLocalStorage<Collection[]>('collections', []);
  const [showColModal, setShowColModal] = useState(false);
  const [showItemModal, setShowItemModal] = useState<string | null>(null); // collection id
  const [editCol, setEditCol] = useState<Collection | null>(null);
  const [editItem, setEditItem] = useState<CollectionItem | null>(null);
  const [colForm, setColForm] = useState(EMPTY_COLLECTION);
  const [itemForm, setItemForm] = useState(EMPTY_ITEM);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  function toggleExpand(id: string) {
    setExpanded(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }

  function openAddCol() { setEditCol(null); setColForm(EMPTY_COLLECTION); setShowColModal(true); }
  function openEditCol(col: Collection) {
    setEditCol(col);
    setColForm({ name: col.name, description: col.description || '', color: col.color });
    setShowColModal(true);
  }

  function saveCol() {
    if (!colForm.name.trim()) return;
    if (editCol) {
      setCollections(prev => prev.map(c => c.id === editCol.id ? { ...c, ...colForm } : c));
    } else {
      setCollections(prev => [...prev, { ...colForm, id: generateId(), items: [], createdAt: new Date().toISOString() }]);
    }
    setShowColModal(false);
  }

  function deleteCol(id: string) { setCollections(prev => prev.filter(c => c.id !== id)); }

  function openAddItem(colId: string) {
    setEditItem(null);
    setItemForm(EMPTY_ITEM);
    setShowItemModal(colId);
  }

  function openEditItem(colId: string, item: CollectionItem) {
    setEditItem(item);
    setItemForm({ title: item.title, url: item.url || '', notes: item.notes || '' });
    setShowItemModal(colId);
  }

  function saveItem() {
    if (!itemForm.title.trim() || !showItemModal) return;
    setCollections(prev => prev.map(col => {
      if (col.id !== showItemModal) return col;
      if (editItem) {
        return { ...col, items: col.items.map(i => i.id === editItem.id ? { ...i, ...itemForm } : i) };
      }
      const newItem: CollectionItem = { ...itemForm, id: generateId(), createdAt: new Date().toISOString() };
      return { ...col, items: [newItem, ...col.items] };
    }));
    setShowItemModal(null);
  }

  function deleteItem(colId: string, itemId: string) {
    setCollections(prev => prev.map(col =>
      col.id === colId ? { ...col, items: col.items.filter(i => i.id !== itemId) } : col
    ));
  }

  return (
    <Layout
      title="Collections"
      subtitle={`${collections.length} collections · ${collections.reduce((s, c) => s + c.items.length, 0)} items`}
      action={
        <button className="btn btn-primary btn-lg" onClick={openAddCol}>
          <Plus size={13} /> New Collection
        </button>
      }
    >
      {collections.length === 0 ? (
        <div className="text-center py-16">
          <BookMarked size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">No collections yet. Create one to get started.</p>
          <button className="btn btn-primary mt-4" onClick={openAddCol}><Plus size={12} /> Create collection</button>
        </div>
      ) : (
        <div className="space-y-3">
          {collections.map(col => {
            const isExpanded = expanded.has(col.id);
            return (
              <div key={col.id} className="card overflow-hidden">
                {/* Collection header */}
                <div
                  className="flex items-center gap-3 px-5 py-4 cursor-pointer hover:bg-gray-50/50"
                  style={{ borderLeft: `3px solid ${col.color === '#F3F4F6' ? '#D1D5DB' : col.color.replace('F', 'A')}` }}
                  onClick={() => toggleExpand(col.id)}
                >
                  {isExpanded ? <ChevronDown size={14} className="text-gray-400 shrink-0" /> : <ChevronRight size={14} className="text-gray-400 shrink-0" />}
                  <div
                    className="w-6 h-6 rounded-md shrink-0"
                    style={{ backgroundColor: col.color }}
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-gray-800">{col.name}</p>
                    {col.description && <p className="text-[10px] text-gray-400">{col.description}</p>}
                  </div>
                  <span className="badge bg-gray-50 border border-gray-100 text-gray-500">{col.items.length} items</span>
                  <div className="flex gap-1 ml-2" onClick={e => e.stopPropagation()}>
                    <button className="btn btn-sm btn-default" onClick={() => openAddItem(col.id)}><Plus size={10} /></button>
                    <button className="btn btn-sm btn-default" onClick={() => openEditCol(col)}><Edit2 size={10} /></button>
                    <button className="btn btn-sm btn-danger" onClick={() => deleteCol(col.id)}><Trash2 size={10} /></button>
                  </div>
                </div>

                {/* Items */}
                {isExpanded && (
                  <div className="border-t border-gray-100">
                    {col.items.length === 0 ? (
                      <div className="py-6 text-center">
                        <p className="text-xs text-gray-400">Empty collection.</p>
                        <button className="btn btn-default mt-2 btn-sm" onClick={() => openAddItem(col.id)}>
                          <Plus size={10} /> Add item
                        </button>
                      </div>
                    ) : (
                      <div className="divide-y divide-gray-50">
                        {col.items.map(item => (
                          <div key={item.id} className="flex items-center gap-3 px-5 py-2.5 group hover:bg-gray-50/50">
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2">
                                <p className="text-xs font-medium text-gray-700">{item.title}</p>
                                {item.url && (
                                  <a href={item.url} target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:text-blue-600" onClick={e => e.stopPropagation()}>
                                    <ExternalLink size={10} />
                                  </a>
                                )}
                              </div>
                              {item.notes && <p className="text-[10px] text-gray-400 mt-0.5 line-clamp-1">{item.notes}</p>}
                              {item.url && <p className="text-[10px] text-gray-400 mt-0.5 truncate max-w-xs">{item.url}</p>}
                            </div>
                            <span className="text-[10px] text-gray-300">{formatDate(item.createdAt)}</span>
                            <div className="flex gap-1 opacity-0 group-hover:opacity-100">
                              <button className="btn btn-sm btn-default" onClick={() => openEditItem(col.id, item)}><Edit2 size={10} /></button>
                              <button className="btn btn-sm btn-danger" onClick={() => deleteItem(col.id, item.id)}><Trash2 size={10} /></button>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Collection Modal */}
      <Modal open={showColModal} onClose={() => setShowColModal(false)} title={editCol ? 'Edit Collection' : 'New Collection'}>
        <div className="space-y-3">
          <div>
            <label className="label">Name *</label>
            <input className="input" placeholder="e.g. Useful links, Resources..." value={colForm.name} onChange={e => setColForm(f => ({ ...f, name: e.target.value }))} />
          </div>
          <div>
            <label className="label">Description</label>
            <input className="input" placeholder="What is this collection for?" value={colForm.description} onChange={e => setColForm(f => ({ ...f, description: e.target.value }))} />
          </div>
          <div>
            <label className="label flex items-center gap-1"><Palette size={11} /> Color</label>
            <div className="flex gap-2 flex-wrap">
              {COLORS.map(color => (
                <button
                  key={color}
                  className={cn('w-7 h-7 rounded-lg border-2', colForm.color === color ? 'border-gray-900' : 'border-transparent')}
                  style={{ backgroundColor: color }}
                  onClick={() => setColForm(f => ({ ...f, color }))}
                />
              ))}
            </div>
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button className="btn btn-default btn-lg" onClick={() => setShowColModal(false)}>Cancel</button>
            <button className="btn btn-primary btn-lg" onClick={saveCol}>{editCol ? 'Save' : 'Create'}</button>
          </div>
        </div>
      </Modal>

      {/* Item Modal */}
      <Modal open={!!showItemModal} onClose={() => setShowItemModal(null)} title={editItem ? 'Edit Item' : 'Add Item'}>
        <div className="space-y-3">
          <div>
            <label className="label">Title *</label>
            <input className="input" placeholder="Item title..." value={itemForm.title} onChange={e => setItemForm(f => ({ ...f, title: e.target.value }))} />
          </div>
          <div>
            <label className="label">URL</label>
            <input className="input" placeholder="https://..." value={itemForm.url} onChange={e => setItemForm(f => ({ ...f, url: e.target.value }))} />
          </div>
          <div>
            <label className="label">Notes</label>
            <textarea className="input resize-none" rows={2} placeholder="Why is this useful?" value={itemForm.notes} onChange={e => setItemForm(f => ({ ...f, notes: e.target.value }))} />
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button className="btn btn-default btn-lg" onClick={() => setShowItemModal(null)}>Cancel</button>
            <button className="btn btn-primary btn-lg" onClick={saveItem}>{editItem ? 'Save' : 'Add item'}</button>
          </div>
        </div>
      </Modal>
    </Layout>
  );
}
