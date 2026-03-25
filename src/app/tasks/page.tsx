'use client';

import { useState } from 'react';
import Layout from '@/components/Layout';
import Modal from '@/components/Modal';
import { useSyncedCollection } from '@/hooks/useSyncedCollection';
import { Task } from '@/lib/types';
import {
  generateId, formatDate, daysUntil, priorityColor,
  statusColor, categoryIcon, cn
} from '@/lib/utils';
import {
  Plus, CheckCircle2, Circle, Clock,
  Trash2, Mail, AlertCircle
} from 'lucide-react';

const EMPTY_TASK: Omit<Task, 'id' | 'createdAt'> = {
  title: '',
  description: '',
  status: 'todo',
  priority: 'medium',
  assignedTo: '',
  deadline: '',
  tags: [],
  category: 'other',
  emailNotification: false,
};

export default function TasksPage() {
  const [tasks, setTasks, sync] = useSyncedCollection<Task[]>('tasks', 'tasks', []);
  const [showModal, setShowModal] = useState(false);
  const [editTask, setEditTask] = useState<Task | null>(null);
  const [form, setForm] = useState(EMPTY_TASK);
  const [filter, setFilter] = useState<'all' | 'todo' | 'in-progress' | 'done'>('all');
  const [catFilter, setCatFilter] = useState<string>('all');
  const [tagInput, setTagInput] = useState('');
  const [emailStatus, setEmailStatus] = useState<{ id: string; msg: string } | null>(null);

  function openAdd() {
    setEditTask(null);
    setForm(EMPTY_TASK);
    setTagInput('');
    setShowModal(true);
  }

  function openEdit(task: Task) {
    setEditTask(task);
    setForm({
      title: task.title,
      description: task.description || '',
      status: task.status,
      priority: task.priority,
      assignedTo: task.assignedTo || '',
      deadline: task.deadline || '',
      tags: task.tags,
      category: task.category,
      emailNotification: task.emailNotification,
    });
    setTagInput('');
    setShowModal(true);
  }

  function saveTask() {
    if (!form.title.trim()) return;
    if (editTask) {
      setTasks(prev => prev.map(t => t.id === editTask.id ? { ...editTask, ...form } : t));
    } else {
      const newTask: Task = {
        ...form,
        id: generateId(),
        createdAt: new Date().toISOString(),
      };
      setTasks(prev => [newTask, ...prev]);
    }
    setShowModal(false);
  }

  function toggleStatus(task: Task) {
    const next: Task['status'] = task.status === 'done' ? 'todo' : task.status === 'todo' ? 'in-progress' : 'done';
    setTasks(prev => prev.map(t => t.id === task.id ? { ...t, status: next } : t));
  }

  function deleteTask(id: string) {
    setTasks(prev => prev.filter(t => t.id !== id));
  }

  async function sendEmailAlert(task: Task) {
    try {
      const res = await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subject: `⏰ Deadline Alert: ${task.title}`,
          text: `Your task "${task.title}" is due on ${formatDate(task.deadline!)}. Priority: ${task.priority}.`,
          taskId: task.id,
        }),
      });
      const data = await res.json();
      setEmailStatus({ id: task.id, msg: data.success ? 'Email sent!' : 'Failed to send' });
      setTimeout(() => setEmailStatus(null), 3000);
    } catch {
      setEmailStatus({ id: task.id, msg: 'Email error' });
    }
  }

  const addTag = () => {
    const t = tagInput.trim();
    if (t && !form.tags.includes(t)) {
      setForm(f => ({ ...f, tags: [...f.tags, t] }));
    }
    setTagInput('');
  };

  const filtered = tasks
    .filter(t => filter === 'all' || t.status === filter)
    .filter(t => catFilter === 'all' || t.category === catFilter);

  const counts = {
    all: tasks.length,
    todo: tasks.filter(t => t.status === 'todo').length,
    'in-progress': tasks.filter(t => t.status === 'in-progress').length,
    done: tasks.filter(t => t.status === 'done').length,
  };

  return (
    <Layout
      title="Tasks"
      subtitle={`${counts.all} total · ${counts.todo} to do · ${counts['in-progress']} in progress${sync.syncing ? ' · syncing...' : ''}`}
      action={
        <button className="btn btn-primary btn-lg" onClick={openAdd}>
          <Plus size={13} /> New Task
        </button>
      }
    >
      {sync.error && (
        <div className="mb-4 text-xs text-amber-700 bg-amber-50 border border-amber-100 rounded-md px-3 py-2">
          Cloud sync issue: {sync.error}
        </div>
      )}
      {/* Filters */}
      <div className="flex items-center gap-2 mb-5 flex-wrap">
        <div className="flex items-center gap-1 bg-white border border-gray-200 rounded-lg p-1">
          {(['all', 'todo', 'in-progress', 'done'] as const).map(s => (
            <button
              key={s}
              onClick={() => setFilter(s)}
              className={cn(
                'px-2.5 py-1 rounded-md text-[11px] font-medium capitalize',
                filter === s ? 'bg-gray-900 text-white' : 'text-gray-500 hover:text-gray-700'
              )}
            >
              {s === 'in-progress' ? 'In Progress' : s.charAt(0).toUpperCase() + s.slice(1)}
              <span className="ml-1 opacity-60">{counts[s]}</span>
            </button>
          ))}
        </div>

        <select
          value={catFilter}
          onChange={e => setCatFilter(e.target.value)}
          className="input py-1.5 w-auto text-xs"
        >
          <option value="all">All categories</option>
          {['coding', 'blog', 'meeting', 'reading', 'other'].map(c => (
            <option key={c} value={c}>{c.charAt(0).toUpperCase() + c.slice(1)}</option>
          ))}
        </select>
      </div>

      {/* Task list */}
      {filtered.length === 0 ? (
        <div className="text-center py-16">
          <CheckCircle2 size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">No tasks found.</p>
          <button className="btn btn-primary mt-4" onClick={openAdd}>
            <Plus size={12} /> Add first task
          </button>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map(task => {
            const days = task.deadline ? daysUntil(task.deadline) : null;
            const isOverdue = days !== null && days < 0 && task.status !== 'done';
            const isDueSoon = days !== null && days <= 3 && days >= 0 && task.status !== 'done';

            return (
              <div
                key={task.id}
                className={cn(
                  'card px-4 py-3 flex items-start gap-3 group',
                  task.status === 'done' && 'opacity-60',
                  isOverdue && 'border-red-100 bg-red-50/20'
                )}
              >
                {/* Toggle button */}
                <button
                  onClick={() => toggleStatus(task)}
                  className="mt-0.5 text-gray-300 hover:text-gray-700 shrink-0"
                  title={`Status: ${task.status}`}
                >
                  {task.status === 'done'
                    ? <CheckCircle2 size={16} className="text-green-500" />
                    : task.status === 'in-progress'
                    ? <Clock size={16} className="text-blue-400" />
                    : <Circle size={16} />
                  }
                </button>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-sm">{categoryIcon(task.category)}</span>
                    <p className={cn(
                      'text-sm font-medium text-gray-800',
                      task.status === 'done' && 'line-through text-gray-400'
                    )}>
                      {task.title}
                    </p>
                    <span className={`badge border ${priorityColor(task.priority)}`}>{task.priority}</span>
                    <span className={`badge border ${statusColor(task.status)}`}>{task.status}</span>
                    {task.tags.map(tag => (
                      <span key={tag} className="badge bg-gray-50 text-gray-500 border border-gray-100">
                        {tag}
                      </span>
                    ))}
                  </div>

                  {task.description && (
                    <p className="text-[11px] text-gray-400 mt-1 line-clamp-1">{task.description}</p>
                  )}

                  <div className="flex items-center gap-3 mt-2 flex-wrap">
                    {task.deadline && (
                      <span className={cn(
                        'flex items-center gap-1 text-[10px]',
                        isOverdue ? 'text-red-500' : isDueSoon ? 'text-amber-500' : 'text-gray-400'
                      )}>
                        {isOverdue && <AlertCircle size={10} />}
                        {isOverdue ? 'Overdue' : isDueSoon ? `Due in ${days}d` : `Due ${formatDate(task.deadline)}`}
                      </span>
                    )}
                    {task.assignedTo && (
                      <span className="text-[10px] text-gray-400">
                        → {task.assignedTo}
                      </span>
                    )}
                  </div>

                  {emailStatus?.id === task.id && (
                    <p className="text-[10px] text-green-600 mt-1">{emailStatus.msg}</p>
                  )}
                </div>

                {/* Actions */}
                <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 shrink-0">
                  {task.deadline && task.emailNotification && (
                    <button
                      className="btn btn-sm btn-default"
                      onClick={() => sendEmailAlert(task)}
                      title="Send email alert"
                    >
                      <Mail size={10} />
                    </button>
                  )}
                  <button
                    className="btn btn-sm btn-default"
                    onClick={() => openEdit(task)}
                  >
                    Edit
                  </button>
                  <button
                    className="btn btn-sm btn-danger"
                    onClick={() => deleteTask(task.id)}
                  >
                    <Trash2 size={10} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Add/Edit Modal */}
      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editTask ? 'Edit Task' : 'New Task'}
      >
        <div className="space-y-3">
          <div>
            <label className="label">Title *</label>
            <input
              className="input"
              placeholder="What needs to be done?"
              value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
            />
          </div>

          <div>
            <label className="label">Description</label>
            <textarea
              className="input resize-none"
              rows={2}
              placeholder="More details..."
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Status</label>
              <select className="input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as Task['status'] }))}>
                <option value="todo">To Do</option>
                <option value="in-progress">In Progress</option>
                <option value="done">Done</option>
              </select>
            </div>
            <div>
              <label className="label">Priority</label>
              <select className="input" value={form.priority} onChange={e => setForm(f => ({ ...f, priority: e.target.value as Task['priority'] }))}>
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Category</label>
              <select className="input" value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value as Task['category'] }))}>
                <option value="coding">💻 Coding</option>
                <option value="blog">✍️ Blog</option>
                <option value="meeting">📅 Meeting</option>
                <option value="reading">📚 Reading</option>
                <option value="other">📌 Other</option>
              </select>
            </div>
            <div>
              <label className="label">Deadline</label>
              <input type="date" className="input" value={form.deadline} onChange={e => setForm(f => ({ ...f, deadline: e.target.value }))} />
            </div>
          </div>

          <div>
            <label className="label">Assign To</label>
            <input
              className="input"
              placeholder="Name or email"
              value={form.assignedTo}
              onChange={e => setForm(f => ({ ...f, assignedTo: e.target.value }))}
            />
          </div>

          <div>
            <label className="label">Tags</label>
            <div className="flex gap-1.5">
              <input
                className="input flex-1"
                placeholder="Add tag, press Enter"
                value={tagInput}
                onChange={e => setTagInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), addTag())}
              />
              <button className="btn btn-default" onClick={addTag}>Add</button>
            </div>
            {form.tags.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-1.5">
                {form.tags.map(tag => (
                  <span key={tag} className="badge bg-gray-100 text-gray-600 border border-gray-200 cursor-pointer hover:bg-red-50 hover:text-red-500"
                    onClick={() => setForm(f => ({ ...f, tags: f.tags.filter(t => t !== tag) }))}>
                    {tag} ×
                  </span>
                ))}
              </div>
            )}
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={form.emailNotification}
              onChange={e => setForm(f => ({ ...f, emailNotification: e.target.checked }))}
              className="rounded border-gray-300"
            />
            <span className="text-xs text-gray-600">Email alert when deadline is near</span>
          </label>

          <div className="flex justify-end gap-2 pt-2">
            <button className="btn btn-default btn-lg" onClick={() => setShowModal(false)}>Cancel</button>
            <button className="btn btn-primary btn-lg" onClick={saveTask}>
              {editTask ? 'Save changes' : 'Create task'}
            </button>
          </div>
        </div>
      </Modal>
    </Layout>
  );
}
