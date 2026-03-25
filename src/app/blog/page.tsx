'use client';

import { useState } from 'react';
import Layout from '@/components/Layout';
import { useLocalStorage } from '@/hooks/useLocalStorage';
import { BlogPost } from '@/lib/types';
import { generateId, formatDate, cn } from '@/lib/utils';
import { Plus, FileText, Edit2, Trash2, Eye, EyeOff, ArrowLeft, Save } from 'lucide-react';

const EMPTY: Omit<BlogPost, 'id' | 'createdAt' | 'updatedAt'> = {
  title: '',
  content: '',
  excerpt: '',
  status: 'draft',
  tags: [],
};

function SimpleMarkdown({ text }: { text: string }) {
  const lines = text.split('\n');
  return (
    <div className="prose-custom text-sm text-gray-700 space-y-2 leading-relaxed">
      {lines.map((line, i) => {
        if (line.startsWith('## ')) return <h2 key={i} className="text-base font-semibold text-gray-900 mt-4">{line.slice(3)}</h2>;
        if (line.startsWith('# ')) return <h1 key={i} className="text-lg font-bold text-gray-900 mt-4">{line.slice(2)}</h1>;
        if (line.startsWith('### ')) return <h3 key={i} className="text-sm font-semibold text-gray-800 mt-3">{line.slice(4)}</h3>;
        if (line.startsWith('- ')) return <li key={i} className="text-xs text-gray-600 list-disc ml-4">{line.slice(2)}</li>;
        if (line.startsWith('> ')) return <blockquote key={i} className="border-l-2 border-gray-200 pl-3 text-gray-500 text-xs italic">{line.slice(2)}</blockquote>;
        if (line === '') return <div key={i} className="h-1" />;
        return <p key={i} className="text-xs text-gray-600 leading-relaxed">{line}</p>;
      })}
    </div>
  );
}

export default function BlogPage() {
  const [posts, setPosts] = useLocalStorage<BlogPost[]>('blog_posts', []);
  const [editing, setEditing] = useState<BlogPost | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [preview, setPreview] = useState(false);
  const [tagInput, setTagInput] = useState('');
  const [filter, setFilter] = useState<'all' | 'draft' | 'published'>('all');

  function openNew() {
    setIsNew(true);
    setEditing(null);
    setForm(EMPTY);
    setTagInput('');
    setPreview(false);
  }

  function openEdit(post: BlogPost) {
    setEditing(post);
    setIsNew(false);
    setForm({ title: post.title, content: post.content, excerpt: post.excerpt || '', status: post.status, tags: post.tags });
    setTagInput('');
    setPreview(false);
  }

  function save(status?: BlogPost['status']) {
    if (!form.title.trim()) return;
    const now = new Date().toISOString();
    const finalStatus = status || form.status;
    if (editing) {
      setPosts(prev => prev.map(p => p.id === editing.id ? { ...p, ...form, status: finalStatus, updatedAt: now } : p));
      setEditing(null);
    } else {
      const newPost: BlogPost = { ...form, status: finalStatus, id: generateId(), createdAt: now, updatedAt: now };
      setPosts(prev => [newPost, ...prev]);
      setIsNew(false);
    }
  }

  function deletePost(id: string) { setPosts(prev => prev.filter(p => p.id !== id)); }
  function togglePublish(post: BlogPost) {
    setPosts(prev => prev.map(p => p.id === post.id ? { ...p, status: p.status === 'published' ? 'draft' : 'published', updatedAt: new Date().toISOString() } : p));
  }

  const addTag = () => {
    const t = tagInput.trim();
    if (t && !form.tags.includes(t)) setForm(f => ({ ...f, tags: [...f.tags, t] }));
    setTagInput('');
  };

  const isEditing = editing || isNew;
  const filtered = posts.filter(p => filter === 'all' || p.status === filter);
  const drafts = posts.filter(p => p.status === 'draft').length;
  const published = posts.filter(p => p.status === 'published').length;

  // Editor view
  if (isEditing) {
    return (
      <Layout
        title={isNew ? 'New Post' : 'Edit Post'}
        action={
          <div className="flex items-center gap-2">
            <button className="btn btn-default btn-lg" onClick={() => { setEditing(null); setIsNew(false); }}>
              <ArrowLeft size={13} /> Back
            </button>
            <button
              className="btn btn-default btn-lg"
              onClick={() => setPreview(!preview)}
            >
              {preview ? <><EyeOff size={13} /> Edit</> : <><Eye size={13} /> Preview</>}
            </button>
            <button className="btn btn-default btn-lg" onClick={() => save('draft')}>
              <Save size={13} /> Save Draft
            </button>
            <button className="btn btn-primary btn-lg" onClick={() => save('published')}>
              Publish
            </button>
          </div>
        }
      >
        <div className="max-w-3xl mx-auto">
          {!preview ? (
            <div className="space-y-4">
              <input
                className="input text-lg font-semibold py-3"
                placeholder="Post title..."
                value={form.title}
                onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              />
              <input
                className="input text-sm"
                placeholder="Short excerpt (optional)..."
                value={form.excerpt}
                onChange={e => setForm(f => ({ ...f, excerpt: e.target.value }))}
              />
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="label">Content (Markdown supported)</label>
                  <span className="text-[10px] text-gray-400">{form.content.length} chars · ~{Math.ceil(form.content.split(' ').length / 200)} min read</span>
                </div>
                <textarea
                  className="input resize-none font-mono text-xs leading-relaxed"
                  rows={20}
                  placeholder="Write your post here... Markdown is supported.&#10;&#10;# Heading 1&#10;## Heading 2&#10;- List item&#10;> Blockquote"
                  value={form.content}
                  onChange={e => setForm(f => ({ ...f, content: e.target.value }))}
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
                  <div className="flex gap-1.5 mt-2 flex-wrap">
                    {form.tags.map(tag => (
                      <span
                        key={tag}
                        className="badge bg-gray-100 text-gray-600 border border-gray-200 cursor-pointer hover:bg-red-50 hover:text-red-500"
                        onClick={() => setForm(f => ({ ...f, tags: f.tags.filter(t => t !== tag) }))}
                      >
                        {tag} ×
                      </span>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="card p-8">
              <div className="mb-6 pb-4 border-b border-gray-100">
                <h1 className="text-xl font-bold text-gray-900 mb-2">{form.title || 'Untitled'}</h1>
                {form.excerpt && <p className="text-sm text-gray-500 italic">{form.excerpt}</p>}
                <div className="flex gap-2 mt-3 flex-wrap">
                  {form.tags.map(tag => (
                    <span key={tag} className="badge bg-gray-100 text-gray-600 border border-gray-200">#{tag}</span>
                  ))}
                </div>
              </div>
              <SimpleMarkdown text={form.content} />
            </div>
          )}
        </div>
      </Layout>
    );
  }

  // List view
  return (
    <Layout
      title="Blog"
      subtitle={`${drafts} drafts · ${published} published`}
      action={
        <button className="btn btn-primary btn-lg" onClick={openNew}>
          <Plus size={13} /> New Post
        </button>
      }
    >
      {/* Filter */}
      <div className="flex items-center gap-1.5 mb-5">
        {(['all', 'draft', 'published'] as const).map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={cn('btn btn-sm capitalize', filter === f ? 'btn-primary' : 'btn-default')}
          >
            {f} {f === 'draft' ? `(${drafts})` : f === 'published' ? `(${published})` : `(${posts.length})`}
          </button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <div className="text-center py-16">
          <FileText size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">No posts yet.</p>
          <button className="btn btn-primary mt-4" onClick={openNew}><Plus size={12} /> Write first post</button>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map(post => (
            <div key={post.id} className="card px-5 py-4 flex items-start gap-4 group hover:border-gray-200">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap mb-1">
                  <p className="text-sm font-semibold text-gray-900">{post.title}</p>
                  <span className={cn('badge border', post.status === 'published' ? 'bg-green-50 text-green-700 border-green-100' : 'bg-gray-50 text-gray-500 border-gray-100')}>
                    {post.status}
                  </span>
                </div>
                {post.excerpt && <p className="text-xs text-gray-500 line-clamp-1 mb-2">{post.excerpt}</p>}
                <div className="flex items-center gap-3 flex-wrap">
                  <span className="text-[10px] text-gray-400">{formatDate(post.updatedAt)}</span>
                  <span className="text-[10px] text-gray-400">~{Math.ceil(post.content.split(' ').length / 200)} min read</span>
                  <span className="text-[10px] text-gray-400">{post.content.length} chars</span>
                  {post.tags.map(tag => (
                    <span key={tag} className="badge bg-gray-50 text-gray-500 border border-gray-100">#{tag}</span>
                  ))}
                </div>
              </div>
              <div className="flex gap-1 opacity-0 group-hover:opacity-100 shrink-0">
                <button
                  className={cn('btn btn-sm', post.status === 'published' ? 'btn-default' : 'btn-success')}
                  onClick={() => togglePublish(post)}
                  title={post.status === 'published' ? 'Unpublish' : 'Publish'}
                >
                  {post.status === 'published' ? <EyeOff size={10} /> : <Eye size={10} />}
                  {post.status === 'published' ? 'Unpublish' : 'Publish'}
                </button>
                <button className="btn btn-sm btn-default" onClick={() => openEdit(post)}><Edit2 size={10} /></button>
                <button className="btn btn-sm btn-danger" onClick={() => deletePost(post.id)}><Trash2 size={10} /></button>
              </div>
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}
