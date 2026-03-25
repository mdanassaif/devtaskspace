'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import LogoutButton from './LogoutButton';

interface LayoutProps {
	title?: string;
	subtitle?: string;
	action?: React.ReactNode;
	children: React.ReactNode;
}

export default function Layout({ title, subtitle, action, children }: LayoutProps) {
	const pathname = usePathname();
	const showBackToOverview = pathname !== '/' && pathname !== '';

	return (
		<div className="px-4 py-9 max-w-6xl mx-auto w-full">
			{(title || subtitle || action || showBackToOverview) && (
				<header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
					<div className="min-w-0 flex-1 space-y-3">
						{showBackToOverview && (
							<div>
								<Link
									href="/"
									className="btn btn-default btn-sm"
									title="Return to your overview: alerts, summary, and links to every area"
									aria-label="Back to overview — main page with summary and shortcuts"
								>
									<ArrowLeft size={16} className="text-gray-500 shrink-0" aria-hidden />
									Back to overview
								</Link>
								<p className="text-xs text-gray-400 mt-2 max-w-sm leading-relaxed">
									That page shows your snapshot, alerts, and shortcuts to all tools.
								</p>
							</div>
						)}
						<div>
							{title && (
								<h1 className="text-2xl font-bold text-gray-900 mb-1.5 tracking-tight" id="page-title">
									{title}
								</h1>
							)}
							{subtitle && (
								<p className="text-[15px] text-gray-500 leading-snug" id={title ? 'page-desc' : undefined}>
									{subtitle}
								</p>
							)}
						</div>
					</div>
					<div className="flex items-center gap-2 shrink-0 sm:pt-1">
						{action}
						<LogoutButton />
					</div>
				</header>
			)}
			<div>{children}</div>
		</div>
	);
}