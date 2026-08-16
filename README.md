# Strategies Migration Platform

**WIL Capstone Project** — an AI integration layer built around Strategies Migration Services'
existing custom CRM, adding case triage, document intelligence, client self-service, and two
new flat-fee service lines (tax compliance & clearance, wills).

## Background

Strategies Migration Services (Immigration Specialists) is a South African immigration
consultancy. Their current public-facing process is a static branching intake form with fully
manual triage behind it. Their internal case/client management runs on a custom CRM whose
frontend lives at [RobertMudzonga/SMSSA-fe](https://github.com/RobertMudzonga/SMSSA-fe).

Per direction from the company's IT manager, this project does **not** replace that CRM. It
builds an AI layer around it — the CRM stays the system of record; this project adds the
intelligence and client-facing channels it currently lacks.

## What this repo contains

| Folder / File | Purpose |
|---|---|
| `WBS.xlsx` | Work Breakdown Structure — all phases, tasks, priorities, statuses, and estimated hours |
| `docs/requirements.md` | Functional & non-functional requirements *(added in Phase 0)* |
| `docs/architecture/` | Architecture, ER, and UML diagrams *(added in Phase 1)* |
| `docs/api/` | API documentation (Swagger/Postman) *(added in Phase 2)* |
| `backend/` | AI Orchestration Layer + CRM Integration Connector *(added in Phase 2)* |
| `frontend/` | Extends the existing SMSSA-fe CRM frontend with AI-powered features *(added in Phase 3)* |
| `mobile/` | Client-facing mobile app *(added in Phase 5)* |
| `docs/test-plan.md` | Test plan and results *(added in Phase 6)* |
| `docs/privacy-note.md` | POPIA-aware Terms of Use / Privacy Note *(added in Phase 6)* |
| `docs/user-guide.md` | Short user guide for Admin, Consultant, and Client roles *(added in Phase 7)* |

*(Folders marked "added in Phase X" don't exist yet at project start — see WBS.xlsx and the
[Project board](../../projects) for current status.)*

## Tech stack

- **Frontend:** React 18 + TypeScript, Vite, Tailwind CSS, shadcn/ui — extending the existing
  SMSSA-fe codebase rather than rebuilding it.
- **Backend / AI layer:** REST API (language/framework TBC in Phase 2) calling the Claude or
  GPT API for all AI agents, behind a CRM Integration Connector.
- **Mobile:** TBC in Phase 5 — scoped to case status, document upload, and messaging only.
- **AI provider:** Anthropic Claude API (or OpenAI GPT API) — one account/key reused across all
  agents, each given a different task-specific prompt.

## Project management

Progress is tracked on the repo's [Project board](../../projects), seeded from `WBS.xlsx`.
Each task is a GitHub Issue labelled by category (`discovery`, `architecture`, `backend`,
`ai-agent`, `frontend`, `mobile`, `qa`, `compliance`, `documentation`, `handoff`) and moved
across columns (Backlog → To Do → In Progress → In Review → Done) as work happens.

## Getting started (current state)

This repo currently holds planning artefacts only (WBS, and this README). To run the existing
CRM frontend this project builds on:

```
git clone https://github.com/RobertMudzonga/SMSSA-fe.git
cd SMSSA-fe
npm install
npm run dev
# open http://localhost:8080
```

Set `VITE_API_BASE` in a `.env.local` file to point at a backend (see the SMSSA-fe README for
details). Instructions for running this project's own backend and mobile app will be added
here once they exist (Phases 2 and 5).

## Status

See `WBS.xlsx` → **Summary** tab for live task counts and % complete per phase, or the
[Project board](../../projects) for the day-to-day view.
