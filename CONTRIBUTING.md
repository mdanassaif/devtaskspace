# Contributing to Stacker

Thanks for helping improve Stacker.

## Before You Start

1. Install dependencies with `npm install`.
2. Copy `.env.example` to `.env.local`.
3. Run the app with `npm run dev`.

## Development Checks

Run these before sharing changes:

```bash
npm run typecheck
npm run lint
npm run build
```

Or use:

```bash
npm run check
```

## Contribution Guidelines

- Keep changes focused and easy to review.
- Preserve local-first behavior unless the change clearly belongs in synced data.
- Prefer small reusable components over page-specific duplication.
- Update docs when setup, behavior, or environment requirements change.
- Do not commit secrets or `.env.local`.

## Good First Areas

- UX polish for planning, collections, and blog flows
- Better empty states and validation feedback
- Deployment docs
- Testing coverage
- Accessibility improvements
