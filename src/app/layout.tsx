import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: {
    default: 'Stacker',
    template: '%s | Stacker',
  },
  description:
    'Open-source-ready operations workspace for tasks, planning, domains, subscriptions, collections, and email alerts.',
  applicationName: 'Stacker',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
