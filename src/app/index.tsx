'use client';

import Layout from '@/components/Layout';
import { useSyncedCollection } from '@/hooks/useSyncedCollection';
import { useLocalStorage } from '@/hooks/useLocalStorage';
import { Task, Domain, Subscription, PlanningItem } from '@/lib/types';
import { daysUntil, formatDate, priorityColor, categoryIcon } from '@/lib/utils';
import {
  CreditCard, Globe, Calendar,
  AlertTriangle, Clock, CheckCircle2, ArrowRight, ArrowUpRight, ExternalLink
} from 'lucide-react';
import Link from 'next/link';

export default function Dashboard() {
  const [tasks] = useSyncedCollection<Task[]>('tasks', 'tasks', []);
  const [domains] = useSyncedCollection<Domain[]>('domains', 'domains', []);
  const [subscriptions] = useSyncedCollection<Subscription[]>('subscriptions', 'subscriptions', []);
  const [planning] = useLocalStorage<PlanningItem[]>('planning', []);

  const pendingTasks = tasks.filter(t => t.status !== 'done');
  const doneTasks = tasks.filter(t => t.status === 'done');
  const criticalDomains = domains.filter(d => daysUntil(d.expiryDate) <= 30);
  const upcomingBilling = subscriptions.filter(s => s.isActive && daysUntil(s.nextBillingDate) <= 7);
  const monthlySpend = subscriptions.filter(s => s.isActive && s.billingCycle === 'monthly')
    .reduce((sum, s) => sum + s.price, 0);
  const yearlySpend = subscriptions.filter(s => s.isActive && s.billingCycle === 'yearly')
    .reduce((sum, s) => sum + s.price / 12, 0);

  const dueIn3DaysCount = tasks.filter(
    t => t.status !== 'done' && t.deadline && daysUntil(t.deadline) >= 0 && daysUntil(t.deadline) <= 3
  ).length;

  const recentTasks = tasks.filter(t => t.status !== 'done').slice(0, 5);
  const overdueCount = tasks.filter(
    t => t.status !== 'done' && t.deadline && daysUntil(t.deadline) < 0
  ).length;
  const completionRate = tasks.length > 0 ? Math.round((doneTasks.length / tasks.length) * 100) : 0;

  const stats = [
    {
      label: 'Pending Tasks',
      value: pendingTasks.length,
      icon: Clock,
      sub: `${doneTasks.length} done`,
      emptySub: 'No active tasks yet',
      color: 'text-amber-600',
      bg: 'bg-amber-50',
      href: '/tasks',
    },
    {
      label: 'Domains',
      value: domains.length,
      icon: Globe,
      sub: criticalDomains.length > 0 ? `${criticalDomains.length} expiring soon` : 'All good',
      emptySub: 'No domains tracked yet',
      color: criticalDomains.length > 0 ? 'text-red-600' : 'text-green-600',
      bg: criticalDomains.length > 0 ? 'bg-red-50' : 'bg-green-50',
      href: '/domains',
    },
    {
      label: 'Monthly Spend',
      value: `$${(monthlySpend + yearlySpend).toFixed(0)}`,
      icon: CreditCard,
      sub: `${subscriptions.filter(s => s.isActive).length} active tools`,
      emptySub: 'No active subscriptions',
      color: 'text-blue-600',
      bg: 'bg-blue-50',
      href: '/subscriptions',
    },
    {
      label: 'Planned Items',
      value: planning.filter(p => p.status !== 'done').length,
      icon: Calendar,
      sub: `${planning.filter(p => p.type === 'blog').length} blog ideas`,
      emptySub: 'No planning items yet',
      color: 'text-purple-600',
      bg: 'bg-purple-50',
      href: '/planning',
    },
  ];

  return (
    <Layout
      title="Overview"
      subtitle="A shared workspace snapshot for tasks, renewals, spend, content planning, and day-to-day operations."
    >
      <div className="card p-5 mb-4 border-gray-200">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="section-title mb-2">Today Snapshot</p>
            <h2 className="text-xl font-semibold text-gray-900">
              {pendingTasks.length} active tasks, {criticalDomains.length} domain alerts
            </h2>
            <p className="text-xs text-gray-500 mt-1.5 leading-snug">
              {overdueCount > 0
                ? `${overdueCount} overdue task${overdueCount > 1 ? 's' : ''} need immediate attention.`
                : 'No overdue tasks. Keep the momentum going.'}
            </p>
          </div>
          <div className="grid grid-cols-3 gap-3 min-w-[280px]">
            <div className="rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
              <p className="text-[11px] text-gray-500">Focus</p>
              <p className="text-base font-semibold text-gray-900">{pendingTasks.length}</p>
            </div>
            <div className="rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
              <p className="text-[11px] text-gray-500">Completion</p>
              <p className="text-base font-semibold text-gray-900">{completionRate}%</p>
            </div>
            <div className="rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
              <p className="text-[11px] text-gray-500">Spend</p>
              <p className="text-base font-semibold text-gray-900">${(monthlySpend + yearlySpend).toFixed(0)}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Compact stats + Important Now + Go To — one row above Priority Queue */}
      <div className="flex flex-col lg:flex-row gap-4 mb-7 items-stretch">
        {/* 4 stat cards: 2×2 grid */}
        <div className="grid grid-cols-2 gap-3 w-full lg:w-[410px] lg:shrink-0">
          {stats.map(stat => (
            <Link href={stat.href} key={stat.label} className="min-w-0">
              <div className="card p-4 h-full hover:border-gray-200 hover:bg-gray-50 cursor-pointer">
                <div className="flex items-center justify-between gap-2 mb-2">
                  <div className={`p-1.5 rounded-md ${stat.bg}`}>
                    <stat.icon size={14} className={stat.color} />
                  </div>
                  <ArrowUpRight size={12} className="text-gray-200 shrink-0" />
                </div>
                <p className="text-xl font-semibold text-gray-900 leading-tight">
                  {typeof stat.value === 'number' && stat.value === 0 ? '—' : stat.value}
                </p>
                <p className="text-xs text-gray-500 mt-0.5">{stat.label}</p>
                <p
                  className={`text-[10px] mt-0.5 line-clamp-2 ${
                    typeof stat.value === 'number' && stat.value === 0 ? 'text-gray-400' : stat.color
                  }`}
                >
                  {typeof stat.value === 'number' && stat.value === 0 ? stat.emptySub : stat.sub}
                </p>
              </div>
            </Link>
          ))}
        </div>

        <div className="flex-1 min-w-0 grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="card p-5 border-gray-200">
            <div className="flex items-center gap-2 mb-3">
              <AlertTriangle size={13} className="text-amber-500" />
              <h3 className="text-sm font-semibold text-gray-700">Important Now</h3>
            </div>
            <p className="text-xs text-gray-500 mb-3">Due dates & renewals.</p>
            <div className="space-y-2.5 text-xs">
              <div className="rounded-lg border border-red-100 bg-red-50/40 px-3 py-2 flex items-center justify-between text-gray-700">
                <span>Tasks overdue</span>
                <span className={`font-medium ${overdueCount > 0 ? 'text-red-600' : 'text-gray-700'}`}>{overdueCount}</span>
              </div>
              <div className="rounded-lg border border-amber-100 bg-amber-50/40 px-3 py-2 flex items-center justify-between text-gray-700">
                <span>Tasks due in 3 days</span>
                <span className={`font-medium ${dueIn3DaysCount > 0 ? 'text-amber-600' : 'text-gray-700'}`}>{dueIn3DaysCount}</span>
              </div>
              <div className="rounded-lg border border-orange-100 bg-orange-50/40 px-3 py-2 flex items-center justify-between text-gray-700">
                <span>Domains expiring (30d)</span>
                <span className={`font-medium ${criticalDomains.length > 0 ? 'text-amber-600' : 'text-gray-700'}`}>{criticalDomains.length}</span>
              </div>
              <div className="rounded-lg border border-blue-100 bg-blue-50/40 px-3 py-2 flex items-center justify-between text-gray-700">
                <span>Billing due (7d)</span>
                <span className={`font-medium ${upcomingBilling.length > 0 ? 'text-blue-600' : 'text-gray-700'}`}>{upcomingBilling.length}</span>
              </div>
            </div>
            <div className="mt-3 flex gap-2">
              <Link href="/tasks" className="btn btn-default btn-sm flex-1 justify-center">
                Tasks
              </Link>
              <Link href="/domains" className="btn btn-default btn-sm flex-1 justify-center">
                Domains
              </Link>
              <Link href="/subscriptions" className="btn btn-default btn-sm flex-1 justify-center">
                Billing
              </Link>
            </div>
          </div>

          <div className="card p-5 border-gray-200">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">Go To</h3>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {[
                { label: 'Tasks', href: '/tasks' },
                { label: 'Domains', href: '/domains' },
                { label: 'Subscriptions', href: '/subscriptions' },
                { label: 'Planning', href: '/planning' },
                { label: 'Collections', href: '/collections' },
                { label: 'Blog', href: '/blog' },
                { label: 'Email Logs', href: '/email-logs' },
                { label: 'Settings', href: '/settings' },
              ].map(route => (
                <Link
                  key={route.href}
                  href={route.href}
                  className="rounded-lg border border-gray-200 bg-white hover:bg-gray-50 px-3 py-2.5 text-xs font-medium text-gray-700 w-full flex items-center justify-between"
                >
                  <span>{route.label}</span>
                  <ExternalLink size={12} className="text-gray-300" />
                </Link>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="card p-5 border-gray-200">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-gray-700">Priority Queue</h3>
          <Link href="/tasks" className="text-xs text-gray-400 hover:text-gray-600 flex items-center gap-0.5">
            View all <ArrowRight size={10} />
          </Link>
        </div>
        {recentTasks.length === 0 ? (
          <div className="text-center py-8">
            <CheckCircle2 size={28} className="text-gray-200 mx-auto mb-2" />
            <p className="text-xs text-gray-400">No pending tasks. Add some!</p>
          </div>
        ) : (
          <div className="space-y-2">
            {recentTasks.map(task => (
              <div key={task.id} className="flex items-center gap-3 p-3 rounded-lg border border-transparent hover:border-gray-100 hover:bg-gray-50 group">
                <span className="text-base">{categoryIcon(task.category)}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium text-gray-800 truncate">{task.title}</p>
                  <p className="text-[10px] text-gray-400 mt-0.5">
                    {task.deadline ? `Due ${formatDate(task.deadline)}` : 'No deadline'}
                  </p>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className={`badge border ${priorityColor(task.priority)}`}>
                    {task.priority}
                  </span>
                  {task.status === 'in-progress' && (
                    <span className="badge border bg-blue-50 text-blue-600 border-blue-100">active</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}
