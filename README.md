# JobMatch — Smart Job Aggregator for Indonesia

> Android job aggregator for Indonesia, free-only and in English. Uses AI-powered matching to help job seekers find relevant opportunities fast.

## Overview

JobMatch aggregates free job listings from Indonesian sources (Adzuna, Arbeitnow, Remotive, JSearch) and matches them against your profile using semantic search. Upload your CV or fill out your background manually, and get ranked job suggestions with AI-powered insights — all without scraping or paying for APIs.

**Key features:**
- Vector-based job matching using embedding similarity
- PDF CV parsing with AI extraction (Gemini Flash)
- Smart filters: salary range, work type (WFO/Remote/Hybrid), match score
- AI chat assistant via 9Router proxy for job-related questions
- Daily job ingestion via scheduled Edge Functions

**Target:** Indonesian job seekers on Android (S23+) who want an ad-free, free-tier-friendly job board experience.

## 1. Non-Negotiables (Senior Calls)
- **No scraping "all internet"** — Use whitelisted free APIs only. Scraping ID boards (Glints/Jobstreet) = ToS/ban. Glassdoor rating dropped for MVP (no free legal API; use SerpAPI later).
- **Backend owns ingestion/matching** — App is dumb UI. No on-device scraping/ML, no API keys in APK.
- **Free-only ID reality:** ~500 jobs/mo via Adzuna (250/mo) + Arbeitnow + Remotive + JSearch free. Accept incomplete coverage. Nullable salary/benefits → show "Not disclosed".
- **UI: Linear/Seek-grade** — Zinc-950/White/Slate-200 border, Blue-600 accent 3% only. Inter font. No purple gradients, no emojis, no glassmorphism. Density > decoration.
- **9Router as proxy** — `NINE_ROUTER_API_KEY` in Supabase Vault only; Edge Function calls `https://api.9router.com/v1/chat/completions` (gemini-2.0-flash). Never in client. TF-IDF local fallback if 429/quota.

## 2. Stack
- **Mobile:** Flutter + Riverpod + go_router + dio + shimmer + flutter_dotenv (client only needs SUPABASE_URL/ANON_KEY)
- **Backend:** Supabase (Postgres + pgvector + Auth + Storage + Edge Functions + pg_cron)
- **AI:** 9Router Combo (gemini-2.0-flash for extract/CV/chat, text-embedding-3-small for embeddings)
- **CI:** GitHub Actions → `flutter build apk --release --split-per-abi` + `r0adk3y/sign-android-release` → GitHub Release (not ephemeral artifact)

## 3. Architecture
```
Flutter (Riverpod)
  │ auth/profile CRUD, job list/detail, filters, CV upload, AI overlay
  ▼
Supabase
  ├─ Auth (email)
  ├─ Postgres + pgvector (profiles, jobs, applications)
  ├─ Storage (cv_pdfs)
  └─ Edge Functions (Deno)
       ├─ cron-ingest (every 6h): fetch Adzuna/Arbeitnow/Remotive/JSearch → dedup (title+company hash) → 9Router extract JSON → embedding → upsert
       ├─ cv-parse: pdf → text → 9Router JSON schema → return prefill
       └─ chat-proxy: stream to 9Router, return chunks via Supabase Realtime/SSE
```

## 4. Data Model
```sql
profiles(id uuid pk fk auth.users, full_name, email, phone, location, summary, skills text[], experience jsonb, education jsonb, pref_type enum, pref_location, cv_text, embedding vector(1536))
jobs(id uuid pk, title, company, website, location, type enum('WFO','Remote','Hybrid'), employment enum('full_time','part_time','contract'), contract_duration, salary_min int, salary_max int, posted_at timestamptz, source, description, responsibilities text, benefits text, workload, apply_url, company_rating numeric nullable, embedding vector(1536), created_at)
applications(user_id fk, job_id fk, status)
```
- `posted_at` stored UTC; query converts `AT TIME ZONE 'Asia/Jakarta'` for sort/display.
- pgvector cosine: `1 - (embedding <=> query_embedding)` → `match_score 0-100`.

## 5. Ingestion Pipeline
1. Cron triggers `ingest` Edge Function.
2. Parallel fetch free sources with `source` tag + `posted_at` normalization.
3. Gemini Flash prompt: extract `{type, employment, duration, salary_min/max, benefits[], responsibilities, workload}` as JSON; salary null if not disclosed.
4. Embedding via 9Router; on 429 fallback to TF-IDF keyword score (no vector).
5. Dedup + upsert. Free tier respects rate limits.

## 6. Matching & Filters
- Profile embedding (skills+summary+experience) vs job embedding → cosine → rank.
- Filters (SQL): `salary BETWEEN`, `type IN (...)`, `ORDER BY match_score|salary|posted_at` + pagination `range(from,to)` 20/page. Timezone handled server-side.
- Match-ability chips: `>85 Highly matched, 70-85 Good, <70 Low`.

## 7. UI/UX Spec
- **Auth → Profile:** CV upload (PDF) or manual form (editable after AI prefill).
- **Loading:** Shimmer skeleton matching card layout, not spinner.
- **List:** White card, 1px Slate-200, 8px radius, title/company/salary chips/ match badge/ posted relative + Jakarta date.
- **Detail:** Bottom sheet / push with all fields + Apply button (external URL).
- **Filter sheet:** Salary range slider, Match asc/desc, Type (WFO/Remote/Hybrid chips), Newest/Oldest.
- **AI Bubble:** Draggable `OverlayEntry`, rounded chat box, header with minimize (−) + close (×), text-only MVP, streaming via Edge proxy.

## 8. Phased Build
**MVP Week 1 — Foundation:**
- `flutter create` + Riverpod + go_router + Supabase init + .env
- Supabase project + tables + RLS + Storage bucket
- Auth + Profile CRUD
- Job cards + shimmer + detail + pagination (mock → Arbeitnow live)
- Filters UI + queries + Asia/Jakarta sort
- GitHub Actions signed APK → Release

**V1 Week 2 — Intelligence:**
- + Adzuna/JSearch/Remotive sources, cron 6h
- CV parse (Storage → Edge → 9Router → prefill)
- pgvector embeddings + cosine ranking + TF-IDF fallback
- Dedup + nullable field handling + timezone correctness

**V2 — Polish:**
- AI bubble overlay + chat-proxy streaming
- Company rating via SerpAPI link (optional)
- FCM push for new high-match jobs
- iOS build (same codebase)

## 9. Repo Structure (target)
```
lib/
  main.dart
  core/{supabase, theme, router, constants}
  features/{auth, profile, jobs, chat}
  widgets/{shimmer_card, filter_sheet, ai_bubble}
supabase/
  functions/{ingest,cv-parse,chat-proxy}
  migrations/
.github/workflows/android.yml
```

## 10. Env
```
# client (.env — committed as .env.example only)
SUPABASE_URL=
SUPABASE_ANON_KEY=
# server (Supabase Vault — never in repo)
NINE_ROUTER_API_KEY=
SUPABASE_SERVICE_ROLE_KEY=
ADZUNA_APP_ID=
ADZUNA_APP_KEY=
```

## 11. Run Locally
```bash
flutter pub get
cp .env.example .env  # fill SUPABASE_*
flutter run
supabase functions serve --env-file supabase/.env
```

## 12. CI — S23+ Install
Push to `main` → Action builds signed APK (`keystore` from GitHub Secrets) → GitHub Release → download on S23+ → allow Unknown Apps → install.

## 13. Session Memory
This README is source of truth. New session → read this first. Do not re-ask stack; follow phases in order. Free-only, ID-focused, no scraping, Vault-only keys.
