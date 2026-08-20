# Repository Guidelines

## Communication Language

Use Japanese as the preferred language for communication with the user. Use another language only when the user requests it.

## Project Structure

This is a TypeScript full-stack app built with Vite, React, Hono, and Cloudflare Workers.

- `src/app/` — browser UI; `App.tsx` is the root component, styles live beside it, and static UI assets belong in `src/app/assets/`.
- `src/worker/index.ts` — backend entry point.
- `src/worker/routes/` — API route implementations.
- `src/worker/db/` — D1 access code.
- `migrations/` — versioned D1 schema changes.
- `public/` — directly served public files.
- `docs/` — product notes.
- `wrangler.json` — Worker entry point and deployment configuration.

## Local Development First

Install dependencies with `pnpm install`, then use `pnpm dev` for everyday work. It starts the Vite development server with hot-module replacement; exercise both the React UI and `/api/` routes locally before considering a deployment.

Run these checks before requesting review:

- `pnpm lint` — lint TypeScript and TSX with Biome.
- `pnpm build` — type-check project references and build production assets.
- `pnpm exec vitest run` — run unit tests with Vitest.
- `pnpm exec playwright test` — run end-to-end tests with Playwright.
- `pnpm check` — type-check, build, and perform a Wrangler dry-run deployment check.
- `pnpm cf-typegen` — regenerate `worker-configuration.d.ts` after changing Worker bindings in `wrangler.json`.

Use Vitest for focused unit tests and name them `*.test.ts` or `*.test.tsx` beside the code they cover. Keep Playwright end-to-end tests in `tests/` and name them `*.spec.ts`. Add or update tests for behaviour changes, and document any manual verification that automated tests do not cover in the pull request.

## Style and Naming

Use TypeScript for application and Worker code. Biome enforces tabs for indentation and double quotes in JavaScript/TypeScript; run `pnpm lint` rather than hand-formatting. Name React components in `PascalCase` (for example, `SubscriptionForm.tsx`), hooks as `useThing`, and ordinary variables/functions in `camelCase`. Keep API endpoints under `/api/` and return explicit JSON responses from Hono handlers.

## Commits and Pull Requests

The repository history currently uses short, imperative subjects (for example, `add: linter library`). Follow that pattern: `Add subscription form`, not `Added changes`. Keep each commit focused. Pull requests should state the user-visible change, list validation commands and results, link relevant issues, and include screenshots for UI changes.

## Cloudflare Worker Changes

Deployment is not the primary feedback loop. Use it only after local checks pass. Before changing Workers APIs, bindings, quotas, or runtime assumptions, consult the current [Cloudflare Workers documentation](https://developers.cloudflare.com/workers/) and regenerate types for binding changes. Never commit secrets; configure them through Cloudflare/Wrangler.

The D1 binding is `DB` and targets `v-subsc-db`. Apply migrations locally before using `--remote`; `pnpm dev` uses local D1 by default. Before remote D1 operations or deployment, run `pnpm exec wrangler whoami` and verify the target.
