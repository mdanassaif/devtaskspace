export interface Task {
  id: string;
  title: string;
  description?: string;
  status: 'todo' | 'in-progress' | 'done';
  priority: 'low' | 'medium' | 'high';
  assignedTo?: string;
  deadline?: string;
  tags: string[];
  category: 'coding' | 'blog' | 'meeting' | 'reading' | 'other';
  emailNotification: boolean;
  createdAt: string;
}

export interface Domain {
  id: string;
  name: string;
  registrar: string;
  expiryDate: string;
  autoRenew: boolean;
  notes?: string;
  cost?: number;
  createdAt: string;
}

export interface Subscription {
  id: string;
  name: string;
  website?: string;
  price: number;
  currency: string;
  billingCycle: 'monthly' | 'yearly' | 'weekly' | 'one-time';
  nextBillingDate: string;
  category: 'tool' | 'hosting' | 'saas' | 'design' | 'ai' | 'other';
  notes?: string;
  isActive: boolean;
  createdAt: string;
}

export interface PlanningItem {
  id: string;
  type: 'blog' | 'meeting' | 'coding' | 'reading' | 'other';
  title: string;
  description?: string;
  status: 'idea' | 'planned' | 'in-progress' | 'done';
  scheduledDate?: string;
  priority: 'low' | 'medium' | 'high';
  notes?: string;
  createdAt: string;
}

export interface CollectionItem {
  id: string;
  title: string;
  url?: string;
  notes?: string;
  createdAt: string;
}

export interface Collection {
  id: string;
  name: string;
  description?: string;
  color: string;
  items: CollectionItem[];
  createdAt: string;
}

export interface BlogPost {
  id: string;
  title: string;
  content: string;
  excerpt?: string;
  status: 'draft' | 'published';
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

export interface EmailLog {
  id: string;
  to: string;
  subject: string;
  body: string;
  status: 'sent' | 'failed' | 'pending';
  relatedId?: string;
  relatedType?: 'task' | 'domain' | 'subscription';
  sentAt: string;
}

export type Priority = 'low' | 'medium' | 'high';
export type Status = 'todo' | 'in-progress' | 'done';
