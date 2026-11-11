# JobMatch — Personal Use Job Portal 

> Ad-free Android job aggregator for the Indonesian tech and professional market. Combines compliant multi-source ingestion, LLM metadata extraction, and `pgvector` cosine similarity ranking to match candidates against relevant roles.
> Created personally because of how bad the job market in Indonesia as a Software Engineer or IT related job. Created in mind because I am tired of applying in LinkedIn, Glints, and other similiar job portal, while also to be a side personal project to hone and explore IT stacks and Skills. 

## Key Features
- **Semantic Vector Matching:** Ranks job listings against a candidate's full profile (`skills + summary + experience`) using 1536-dimensional embeddings and `pgvector` cosine similarity.
- **Automated PDF CV Parsing:** Server-side resume text extraction and structured JSON prefill via Gemini Flash so candidates review rather than type from scratch.
- **Server-Side Smart Filters:** SQL-level filtering across salary bands, work arrangement (`WFO` / `Remote` / `Hybrid`), timezone-normalized recency, and match tiers.
- **Streaming Career Assistant:** Draggable in-app overlay powered by Server-Sent Events (SSE) through an authenticated Edge proxy.
- **Scheduled Multi-Source Ingestion:** Automated 6-hour `pg_cron` pipeline with deterministic deduplication and lexical `TF-IDF` fallback under free-tier rate limits.

## 1. Engineering Trade-Offs & Design Decisions
- **Compliant Public APIs Over Scraping:** Scraping regional boards (e.g., JobStreet, Glints) violates Terms of Service and creates brittle DOM maintenance. Ingestion is restricted to whitelisted free-tier APIs (`Adzuna`, `Arbeitnow`, `Remotive`, `JSearch`). This trades raw volume (~500+ curated roles/month) for legal compliance and stability; undisclosed compensation is stored as `NULL` and surfaced explicitly as `"Not disclosed"`.
- **Zero-Secret Thin Client:** All ingestion, PDF parsing, LLM calls, and vector ranking run on the backend. Third-party credentials (`NINE_ROUTER_API_KEY`, `ADZUNA_APP_KEY`) live strictly inside **Supabase Vault**—never inside the Flutter APK.
- **Graceful `HTTP 429` Degradation:** Upstream free-tier LLM and embedding gateways enforce strict RPM/TPM quotas. When an embedding batch hits `429 Too Many Requests` or times out, matching falls back to server-side `TF-IDF` keyword scoring rather than failing ingestion or user queries.
- **Deterministic Timezone Handling:** Heterogeneous upstream timestamps are normalized to `UTC` (`timestamptz`) at ingestion and converted server-side (`AT TIME ZONE 'Asia/Jakarta'`) for sorting and pagination consistency.
- **High-Density Functional UI:** Built around a neutral palette (`Zinc-950` text, `White` surfaces, `1px Slate-200` borders, restrained `Blue-600` interactive accents, `Inter` typography) and layout-matched shimmer skeletons to prioritize scannability over visual clutter.

## 2. Tech Stack
- **Mobile Client:** Flutter, Dart, `flutter_riverpod`, `go_router`, `dio`, `shimmer`, `flutter_dotenv` (client holds only `SUPABASE_URL` and `SUPABASE_ANON_KEY`)
- **Backend & Database:** Supabase (`PostgreSQL 15+`, `pgvector`, `Auth`, `Storage`, `Deno Edge Functions`, `pg_cron`, Row-Level Security)
- **LLM & Embeddings:** OpenAI-compatible 9Router Gateway (`gemini-2.0-flash` for structured JSON extraction and SSE chat; `text-embedding-3-small` for `vector(1536)` embeddings)
- **CI/CD:** GitHub Actions (`flutter analyze`, `flutter test`, `flutter build apk --release --split-per-abi`, keystore signing via `r0adk3y/sign-android-release` → GitHub Releases)

## 3. System Architecture
```text
Flutter Android Client (Riverpod + go_router + Dio)
  │  Auth & Profile CRUD, paginated feed, SQL filters, PDF CV upload, SSE chat overlay
  ▼
Supabase Backend
  ├─ Auth (Email/JWT + Postgres Row-Level Security)
  ├─ Postgres + pgvector (`profiles`, `jobs`, `applications`)
  ├─ Storage (`cv_pdfs` private bucket scoped per UID)
  └─ Edge Functions (Deno / TypeScript — secrets isolated in Supabase Vault)
       ├─ `ingest` (pg_cron every 6h): fetch Adzuna/Arbeitnow/Remotive/JSearch
       │    → SHA-256 dedup (title + company) → Gemini Flash JSON extraction
       │    → 1536-d embedding generation → idempotent upsert
       ├─ `cv-parse`: PDF text extraction → strict JSON schema prefill
       └─ `chat-proxy`: authenticated SSE stream via 9Router gateway
```

## 4. Database Schema
```sql
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name text,
  email text UNIQUE NOT NULL,
  phone text,
  location text,
  summary text,
  skills text[] DEFAULT '{}',
  experience jsonb DEFAULT '[]'::jsonb,
  education jsonb DEFAULT '[]'::jsonb,
  pref_type work_type_enum,
  pref_location text,
  cv_text text,
  embedding vector(1536)
);

CREATE TABLE jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dedup_hash text UNIQUE NOT NULL,
  title text NOT NULL,
  company text NOT NULL,
  website text,
  location text,
  type work_type_enum NOT NULL,          -- 'WFO' | 'Remote' | 'Hybrid'
  employment employment_type_enum,       -- 'full_time' | 'part_time' | 'contract'
  contract_duration text,
  salary_min integer,                    -- nullable; rendered as "Not disclosed"
  salary_max integer,
  posted_at timestamptz NOT NULL,
  source text NOT NULL,
  description text NOT NULL,
  responsibilities text,
  benefits text,
  workload text,
  apply_url text NOT NULL,
  company_rating numeric(2,1),
  embedding vector(1536),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE applications (
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  job_id uuid REFERENCES jobs(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'saved',
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, job_id)
);
```
- **Cosine Similarity Ranking:** `1 - (jobs.embedding <=> profiles.embedding)` mapped to a `0–100` match score (`>85` Highly Matched, `70–85` Good Match, `<70` Partial Match).

## 5. Ingestion & Matching Pipeline
1. `pg_cron` triggers the `ingest` Edge Function every 6 hours.
2. Source adapters fetch listings in parallel, tag `source`, and normalize `posted_at` to `UTC`.
3. `gemini-2.0-flash` extracts structured metadata (`{type, employment, contract_duration, salary_min, salary_max, benefits, responsibilities, workload}`) under a strict JSON schema.
4. `text-embedding-3-small` generates 1536-d vectors via 9Router, falling back to lexical `TF-IDF` scoring on `HTTP 429` quota exhaustion.
5. Deterministic `(title, company)` hashes deduplicate records before upsert; client queries apply `salary BETWEEN`, `type IN (...)`, `ORDER BY match_score | salary | posted_at`, and 20-item `range(from, to)` pagination.

## 6. UI/UX Architecture
- **Onboarding & Profile:** PDF resume upload with editable AI-prefilled fields alongside manual entry.
- **Feed & Loading States:** Layout-matched shimmer skeletons; high-density cards displaying role, company, compensation chip, match badge, and relative `Asia/Jakarta` timestamp.
- **Detail & Filter Views:** Structured role breakdown with external application handoff; modal filter sheet for salary sliders, work-arrangement chips, and sort order.
- **Streaming Assistant Overlay:** Draggable `OverlayEntry` chat widget with minimize/close controls streaming responses from `chat-proxy`.

## 7. Repository Structure
```text
lib/
  main.dart
  core/{supabase, theme, router, constants}
  features/{auth, profile, jobs, chat}
  widgets/{shimmer_card, filter_sheet, ai_bubble}
supabase/
  functions/{ingest, cv-parse, chat-proxy}
  migrations/
.github/workflows/android.yml
```

## 8. Environment Configuration
```ini
# Client (.env — committed as .env.example only)
# Server (Supabase Vault in production / supabase/.env locally — never committed)
```

## 9. Local Development & CLI Setup
```bash
# 1. Client dependencies & config
flutter pub get
cp .env.example .env

# 2. Local Supabase stack & Edge Functions
supabase start
supabase db reset
supabase functions serve --env-file supabase/.env

# 3. Analyze, test, and run
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
```

## 10. CI/CD & Active Roadmap
Pushes to `main` trigger GitHub Actions to run static analysis, execute tests, build ABI-split release APKs (`--split-per-abi`), sign binaries via GitHub Secrets keystore credentials, and publish artifacts to GitHub Releases.

**Roadmap:**
- [x] Core PostgreSQL + `pgvector` schema, RLS policies, and cosine ranking queries
- [x] Flutter client architecture (`Riverpod` + `go_router`), card feed, shimmer states, and SQL filters
- [x] Automated GitHub Actions signed APK release workflow
- [ ] Additional ingestion adapters (`Adzuna`, `JSearch`, `Remotive`) with retry backoff and dead-letter logging
- [ ] Interactive diff/merge review UI for `cv-parse` PDF extractions
- [ ] Hybrid ranking benchmark (`pgvector` cosine + PostgreSQL `tsvector` Reciprocal Rank Fusion)
- [ ] FCM push notifications for newly ingested high-match (`>85`) roles