export type TaskStatus = 'todo' | 'in-progress' | 'done';
export type TaskPriority = 'low' | 'medium' | 'high';
export type TaskCategory = 'coding' | 'blog' | 'meeting' | 'reading' | 'other';

export interface Task {
  id: string;
  createdAt?: string;
  updatedAt?: string;
  title: string;
  description?: string;
  status: TaskStatus;
  priority: TaskPriority;
  category: TaskCategory;
  deadline?: string;
  assignedTo?: string;
  tags: string[];
  emailNotification?: boolean;
}

export interface Domain {
  id: string;
  createdAt?: string;
  name: string;
  expiryDate: string;
  registrar?: string;
  autoRenew?: boolean;
  cost?: number;
  notes?: string;
}

export type SubscriptionCycle = 'weekly' | 'monthly' | 'yearly' | 'one-time';
export type SubscriptionCategory =
  | 'tool'
  | 'hosting'
  | 'saas'
  | 'design'
  | 'ai'
  | 'other';

export interface Subscription {
  id: string;
  name: string;
  website?: string;
  price: number;
  currency: string;
  billingCycle: SubscriptionCycle;
  nextBillingDate: string;
  category: SubscriptionCategory;
  notes?: string;
  isActive: boolean;
}

export type PlanningType = 'blog' | 'meeting' | 'coding' | 'reading' | 'other';
export type PlanningStatus = 'idea' | 'planned' | 'in-progress' | 'done';

export interface PlanningItem {
  id: string;
  createdAt: string;
  type: PlanningType;
  title: string;
  description?: string;
  status: PlanningStatus;
  scheduledDate?: string;
  priority: TaskPriority;
  notes?: string;
}

export type BlogStatus = 'draft' | 'published';

export interface BlogPost {
  id: string;
  title: string;
  content: string;
  excerpt?: string;
  status: BlogStatus;
  tags: string[];
  createdAt: string;
  updatedAt: string;
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
