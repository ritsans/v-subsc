# Repository Guidelines

## Communication Language

Use Japanese as the preferred language for communication with the user. Use another language only when the user requests it.

## Project Structure

This is a TypeScript full-stack app built with Vite, React, Hono, and Cloudflare Workers. Keep browser UI in `src/app/`: `App.tsx` is the root component, styles live beside it, and static UI assets are in `src/app/assets/`. Keep HTTP routes and Worker code in `src/worker/index.ts`. Put public, directly served files in `public/`, and maintain product notes in `docs/`. `wrangler.json` defines the Worker entry point and deployment configuration.

## Local Development First

Install dependencies with `pnpm install`, then use `pnpm dev` for everyday work. It starts the Vite development server with hot-module replacement; exercise both the React UI and `/api/` routes locally before considering a deployment.

Run these checks before requesting review:

- `pnpm lint` — lint TypeScript and TSX with Biome.
- `pnpm build` — type-check project references and build production assets.
- `pnpm check` — type-check, build, and perform a Wrangler dry-run deployment check.
- `pnpm cf-typegen` — regenerate `worker-configuration.d.ts` after changing Worker bindings in `wrangler.json`.

There is no automated test suite yet. For behaviour changes, add focused tests when introducing a test framework; until then, document manual local verification in the pull request.

## Style and Naming

Use TypeScript for application and Worker code. Biome enforces tabs for indentation and double quotes in JavaScript/TypeScript; run `pnpm lint` rather than hand-formatting. Name React components in `PascalCase` (for example, `SubscriptionForm.tsx`), hooks as `useThing`, and ordinary variables/functions in `camelCase`. Keep API endpoints under `/api/` and return explicit JSON responses from Hono handlers.

## Commits and Pull Requests

The repository history currently uses short, imperative subjects (for example, `add: linter library`). Follow that pattern: `Add subscription form`, not `Added changes`. Keep each commit focused. Pull requests should state the user-visible change, list validation commands and results, link relevant issues, and include screenshots for UI changes.

## Cloudflare Worker Changes

Deployment is not the primary feedback loop. Use it only after local checks pass. Before changing Workers APIs, bindings, quotas, or runtime assumptions, consult the current [Cloudflare Workers documentation](https://developers.cloudflare.com/workers/) and regenerate types for binding changes. Never commit secrets; configure them through Cloudflare/Wrangler.
