'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard, CheckSquare, Globe, CreditCard,
  Calendar, BookMarked, FileText, Layers, Mail
} from 'lucide-react';
import { cn } from '@/lib/utils';

const NAV_ITEMS = [
  { href: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { href: '/tasks', icon: CheckSquare, label: 'Tasks' },
  { href: '/planning', icon: Calendar, label: 'Planning' },
  { href: '/domains', icon: Globe, label: 'Domains' },
  { href: '/subscriptions', icon: CreditCard, label: 'Subscriptions' },
  { href: '/collections', icon: BookMarked, label: 'Collections' },
  { href: '/blog', icon: FileText, label: 'Blog' },
  { href: '/email-logs', icon: Mail, label: 'Email Logs' },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-56 flex-shrink-0 bg-white border-r border-gray-100 flex flex-col h-screen sticky top-0">
      {/* Logo */}
      <div className="px-4 py-5 border-b border-gray-100">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 bg-gray-900 rounded-lg flex items-center justify-center">
            <Layers size={14} className="text-white" />
          </div>
          <span className="text-sm font-semibold text-gray-900 tracking-tight">Stacker</span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        <p className="section-title px-3 mb-3">Workspace</p>
        {NAV_ITEMS.map(({ href, icon: Icon, label }) => {
          const isActive = pathname === href;
          return (
            <Link href={href} key={href} className={cn('nav-item', isActive && 'active')}>
              <Icon size={15} />
              <span>{label}</span>
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="px-4 py-4 border-t border-gray-100">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded-full bg-gray-900 flex items-center justify-center text-[10px] text-white font-semibold">S</div>
          <div>
            <p className="text-xs font-medium text-gray-700">Stacker</p>
            <p className="text-[10px] text-gray-400">Self-hosted workspace</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
