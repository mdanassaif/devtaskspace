
'use client';

import { useState, useEffect } from 'react';
import Layout from '@/components/Layout';
import { cn } from '@/lib/utils';
import { Mail, RefreshCw, CheckCircle, XCircle, Send } from 'lucide-react';

interface EmailLog {
  id: string;
  to: string;
  subject: string;
  text: string;
  status: 'sent' | 'failed';
  sentAt: string;
  resendId?: string;
}

export default function EmailLogsPage() {
  const [logs, setLogs] = useState<EmailLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState<string | null>(null);
  const [msg, setMsg] = useState('');

  async function fetchLogs() {
    setLoading(true);
    try {
      const res = await fetch('/api/send-email');
      const data = await res.json();
      setLogs(data.logs || []);
    } catch {}
    setLoading(false);
  }

  useEffect(() => { fetchLogs(); }, []);

  async function resendEmail(log: EmailLog) {
    if (!log.resendId) return;
    setResending(log.id);
    try {
      const res = await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ resendEmailId: log.resendId }),
      });
      const data = await res.json();
      setMsg(data.success ? 'Resent successfully!' : 'Failed to resend');
      fetchLogs();
    } catch { setMsg('Error'); }
    setResending(null);
    setTimeout(() => setMsg(''), 3000);
  }

  return (
    <Layout
      title="Email Logs"
      subtitle="Track all alerts sent from Stacker"
      action={
        <div className="flex items-center gap-2">
          {msg && <span className="text-[11px] text-green-600">{msg}</span>}
          <button className="btn btn-default btn-lg" onClick={fetchLogs} disabled={loading}>
            <RefreshCw size={13} className={cn(loading && 'animate-spin')} /> Refresh
          </button>
        </div>
      }
    >
      {logs.length === 0 ? (
        <div className="text-center py-16">
          <Mail size={32} className="text-gray-200 mx-auto mb-3" />
          <p className="text-sm text-gray-400">No emails sent yet.</p>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-100">
                {['Status', 'Subject', 'To', 'Sent At', ''].map(h => (
                  <th key={h} className="text-left text-[10px] text-gray-400 font-medium px-4 py-3 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {logs.map(log => (
                <tr key={log.id} className="table-row hover:bg-gray-50/50 group">
                  <td className="px-4 py-3">
                    {log.status === 'sent'
                      ? <CheckCircle size={14} className="text-green-500" />
                      : <XCircle size={14} className="text-red-400" />
                    }
                  </td>
                  <td className="px-4 py-3">
                    <p className="text-xs font-medium text-gray-800">{log.subject}</p>
                    <p className="text-[10px] text-gray-400 mt-0.5 line-clamp-1 max-w-xs">{log.text}</p>
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-500">{log.to}</td>
                  <td className="px-4 py-3 text-xs text-gray-400">{new Date(log.sentAt).toLocaleString()}</td>
                  <td className="px-4 py-3">
                    {log.resendId && (
                      <button
                        className="btn btn-sm btn-default opacity-0 group-hover:opacity-100"
                        onClick={() => resendEmail(log)}
                        disabled={resending === log.id}
                      >
                        <Send size={10} /> {resending === log.id ? '...' : 'Resend'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Layout>
  );
}
