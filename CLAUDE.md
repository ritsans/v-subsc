# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See `AGENTS.md` for repository guidelines: commands (`pnpm dev`/`lint`/`build`/`check`/`cf-typegen`/`deploy`), project structure, communication language, code style/naming, and commit conventions. This file only adds context Claude Code needs that isn't covered there.

## Product context

A subscription-tracking web app (v-subsc), built on the Cloudflare `vite-react-template` (React + Vite + Hono + Cloudflare Workers). The product spec is `docs/mvp-spec.md` (Japanese) — read it before implementing subscription features; it defines the full MVP scope (add/edit/delete subscriptions, JPY/USD pricing without conversion, free-trial day tracking, categories, sorting, totals) and explicitly excludes auth, D1, search, and a few other things for this phase.

Key architectural intent from the spec:
- MVP persists data in browser `localStorage`; production will move to Cloudflare D1, accessed only through the Hono API (`ブラウザ → Hono API → D1`), never directly from the browser.
- Data-access code must stay separated from UI components so the storage backend (localStorage now, API-backed later) can be swapped without touching UI.
- Input/stored data should be validated with Zod; once the Hono API exists, add `@hono/zod-validator` for server-side validation too.
- Currency values are never auto-converted between JPY and USD — they're tracked and summed independently.

The app is currently unmodified boilerplate (`src/app/App.tsx`, `src/worker/index.ts`) — the MVP described in the spec has not been built yet.
