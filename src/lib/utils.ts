import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { differenceInDays, parseISO, format, isValid } from 'date-fns';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function generateId(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

export function formatDate(dateStr: string): string {
  try {
    const date = parseISO(dateStr);
    if (!isValid(date)) return dateStr;
    return format(date, 'MMM dd, yyyy');
  } catch {
    return dateStr;
  }
}

export function formatDateShort(dateStr: string): string {
  try {
    const date = parseISO(dateStr);
    if (!isValid(date)) return dateStr;
    return format(date, 'MMM dd');
  } catch {
    return dateStr;
  }
}

export function daysUntil(dateStr: string): number {
  try {
    const date = parseISO(dateStr);
    if (!isValid(date)) return 999;
    return differenceInDays(date, new Date());
  } catch {
    return 999;
  }
}

export function getExpiryStatus(days: number): 'critical' | 'warning' | 'ok' {
  if (days <= 14) return 'critical';
  if (days <= 45) return 'warning';
  return 'ok';
}

export function getBillingStatus(days: number): 'due-soon' | 'upcoming' | 'ok' {
  if (days <= 3) return 'due-soon';
  if (days <= 7) return 'upcoming';
  return 'ok';
}

export function priorityColor(priority: string): string {
  switch (priority) {
    case 'high': return 'bg-red-50 text-red-600 border-red-100';
    case 'medium': return 'bg-amber-50 text-amber-600 border-amber-100';
    case 'low': return 'bg-green-50 text-green-600 border-green-100';
    default: return 'bg-gray-50 text-gray-600 border-gray-100';
  }
}

export function statusColor(status: string): string {
  switch (status) {
    case 'done': return 'bg-green-50 text-green-700 border-green-100';
    case 'in-progress': return 'bg-blue-50 text-blue-700 border-blue-100';
    case 'todo': return 'bg-gray-50 text-gray-600 border-gray-100';
    default: return 'bg-gray-50 text-gray-600 border-gray-100';
  }
}

export function categoryIcon(category: string): string {
  switch (category) {
    case 'coding': return '💻';
    case 'blog': return '✍️';
    case 'meeting': return '📅';
    case 'reading': return '📚';
    default: return '📌';
  }
}

export function cycleLabel(cycle: string): string {
  switch (cycle) {
    case 'monthly': return '/mo';
    case 'yearly': return '/yr';
    case 'weekly': return '/wk';
    default: return '';
  }
}
