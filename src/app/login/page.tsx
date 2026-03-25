import LoginForm from '@/components/LoginForm';

type LoginPageProps = {
  searchParams?: {
    next?: string | string[];
  };
};

function sanitizeNextPath(nextParam: string | string[] | undefined): string {
  const value = Array.isArray(nextParam) ? nextParam[0] : nextParam;
  if (!value || !value.startsWith('/') || value.startsWith('//')) {
    return '/';
  }
  return value;
}

export default function LoginPage({ searchParams }: LoginPageProps) {
  return <LoginForm redirectTo={sanitizeNextPath(searchParams?.next)} />;
}
