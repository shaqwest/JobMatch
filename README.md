# JobMatch — Personal-Use Tech Job Portal & AI Career Assistant

Ad-free cross-platform job portal (Android & Web) built for software engineers and IT professionals navigating the Indonesian and remote tech job market.

Built out of frustration with cluttered commercial boards (LinkedIn, Glints, JobStreet), **JobMatch** combines compliant public job API ingestion, native **Google Gemini** multimodal PDF resume parsing, JWT-secured **Supabase Deno Edge Functions**, and skill-based match scoring in a clean, zero-ad Flutter interface.

---

## Live Features

- **Multimodal PDF CV Parsing (`cv-parse`):** Upload any single- or multi-column PDF resume; the Edge Function passes raw PDF bytes directly to Gemini (`application/pdf` + strict `application/json` schema) to extract and upsert structured work history, skills, headline, and education into PostgreSQL.
- **Skill-Aware Match Scoring & Smart Filters:** Ranks listings against extracted candidate skills (`Highly matched` ≥ 85%, `Good match` 70–84%, `Low match` < 70%) with filters across salary range (`Rp`), work arrangement (`WFO` / `Remote` / `Hybrid`), and `Asia/Jakarta` (`WIB`) timestamps.
- **Authenticated Career Assistant Overlay (`chat-proxy`):** Draggable, minimizable floating assistant overlay backed by native Google Gemini Flash models with multi-model fallback (`gemini-3.5-flash-lite` → `gemini-2.5-flash` → `gemini-3.8-flash`).
- **Zero-Secret Thin Client & Strict Auth Boundaries:** The Flutter app holds only `SUPABASE_URL` and `SUPABASE_ANON_KEY`. `GOOGLE_API_KEY` and `CRON_SECRET` live strictly in Supabase Secrets, with caller JWT verification, UID-scoped Storage RLS (`cv_pdfs/{uid}/*`), and cron/service-role guards on ingestion.
- **Idempotent Job Ingestion (`ingest`):** Fetches listings from public job APIs (`Arbeitnow`), normalizes unstructured HTML descriptions into structured compensation/arrangement metadata via Gemini, and deduplicates on `apply_url`.

---

## 1. Engineering Trade-Offs & Design Decisions

- **Direct Gemini REST API Over Third-Party Proxies:** Early iterations routed calls through an OpenAI-compatible proxy, introducing extra hops and premature timeouts on multi-page PDFs. Calling `[generativelanguage.googleapis.com/v1beta](https://generativelanguage.googleapis.com/v1beta)` directly from Deno Edge Functions enables native binary PDF ingestion (`inlineData`), deterministic `responseMimeType: "application/json"`, and automatic model fallback on HTTP `429`/`503` spikes.
- **Compliant Public APIs Over DOM Scraping:** Scraping regional boards violates Terms of Service and breaks on layout changes. Ingestion uses compliant public endpoints, storing undisclosed salaries explicitly as `NULL` (surfaced in UI as `"Not disclosed"`).
- **Defense-in-Depth on Edge Functions:** Even where browser CORS preflight requires custom Edge handling, `chat-proxy` and `cv-parse` verify the caller's `Authorization: Bearer <jwt>` against Supabase Auth and enforce path ownership (`{user.id}/`) before touching Storage or `public.profiles`.
- **Graceful Offline/Demo Mode:** If `.env` credentials are absent, the client degrades cleanly into an interactive local demo dataset (`mockJobs()`) rather than crashing on startup.
- **High-Density Functional UI:** Designed with a neutral Zinc/Slate palette, 1px borders, `Inter` typography, and layout-matched `Shimmer` skeletons for fast scanning.

---

## 2. Tech Stack

- **Client (Android & Web):** Flutter, Dart, `flutter_riverpod`, `go_router`, `supabase_flutter`, `file_picker`, `shimmer`, `google_fonts`, `intl`
- **Backend & Database:** Supabase (`PostgreSQL 15+`, `pgvector` extension, Auth, private Storage buckets, Row-Level Security, Deno Edge Functions)
- **AI & Multimodal Extraction:** Google AI Studio / Gemini REST API (`gemini-3.5-flash-lite`, `gemini-2.5-flash`, `gemini-3.8-flash`)
- **CI/CD:** GitHub Actions (Java 21, Gradle 9.5.1 / AGP 9.1.1 release APK build + automated GitHub Releases artifact publishing)

---

## 3. System Architecture

```text
Flutter Client — Android & Web (Riverpod + go_router)
  │  Email Auth, Profile & CV Upload, Ranked Feed, Filters, Draggable Chat Overlay
  ▼
Supabase Cloud Backend
  ├─ Auth (Email/Password JWT + auth.users -> public.profiles trigger)
  ├─ PostgreSQL + pgvector (`profiles`, `jobs`, `applications` with strict RLS)
  ├─ Storage (`cv_pdfs` private bucket — folder RLS scoped to `auth.uid()`)
  └─ Deno Edge Functions (Secrets isolated in Supabase Vault / Edge Secrets)
       ├─ `cv-parse`   (JWT + folder guard): PDF inlineData → Gemini JSON → UPSERT profile
       ├─ `chat-proxy` (JWT guard): Career coaching via Gemini Flash fallback queue
       └─ `ingest`     (x-cron-secret / service_role guard): Public API → Gemini JSON → UPSERT jobs
```

---

## 4. Database Schema Highlights

Managed via incremental SQL migrations in `supabase/migrations/` (`001_init.sql`, `002_cv_persist.sql`, `003_sync_profiles.sql`):

- **`public.profiles`:** `id` (`uuid` FK → `auth.users`), `full_name`, `headline`, `email`, `phone`, `location`, `summary`, `skills` (`text[]`), `experience` (`jsonb`), `education`, `pref_type`, `cv_url`, `cv_filename`, `cv_parsed` (`jsonb`), `embedding` (`vector(1536)`). Protected by `auth.uid() = id` RLS and auto-initialized via `on_auth_user_created` trigger.
- **`public.jobs`:** `id` (`uuid`), `title`, `company`, `website`, `location`, `type` (`WFO` | `Remote` | `Hybrid`), `employment` (`full_time` | `part_time` | `contract`), `contract_duration`, `salary_min`, `salary_max`, `posted_at` (`timestamptz`), `source`, `description`, `responsibilities`, `benefits`, `workload`, `apply_url` (unique index), `embedding` (`vector(1536)`).
- **`public.applications`:** `(user_id, job_id)` composite PK with `status` (`saved` | `draft` | `applied`) and owner-only RLS.

---

## 5. Repository Structure

```text
lib/
  main.dart
  core/          # supabase.dart, router.dart, theme.dart, constants.dart
  features/
    auth/        # auth_gate.dart, auth_provider.dart, login_page.dart
    chat/        # chat_bubble.dart, chat_provider.dart
    jobs/        # job_model.dart, job_filter.dart, jobs_provider.dart, jobs_page.dart, job_detail_page.dart
    profile/     # profile_model.dart, profile_provider.dart, profile_page.dart
  widgets/       # job_card.dart, filter_sheet.dart, shimmer_card.dart, timeline_item.dart
supabase/
  config.toml
  functions/     # chat-proxy/, cv-parse/, ingest/
  migrations/    # 001_init.sql, 002_cv_persist.sql, 003_sync_profiles.sql
docs/
  future_feature.json
test/
  widget_test.dart
.github/workflows/
  android.yml
```

---

## 6. Local Development & Deployment

### Client Setup (Web or Android)
```bash
# 1. Configure public Supabase URL & anon key
cp .env.example .env

# 2. Install dependencies & run unit tests
flutter pub get
flutter test

# 3. Run in Chrome (instant desktop testing) or connected Android device
flutter run -d chrome --dart-define-from-file=.env
```

### Supabase Cloud CLI Workflow
Required Edge Function secrets in Supabase: `GOOGLE_API_KEY` and `CRON_SECRET`.

```bash
npx supabase login
npx supabase link --project-ref <your-project-ref>

# Push new SQL migrations to remote Postgres
npx supabase db push --remote

# Deploy Edge Functions
npx supabase functions deploy --no-verify-jwt
```

---

## 7. Active Engineering Roadmap

Detailed architectural specs live in [`docs/future_feature.json`](docs/future_feature.json):

- [x] Core PostgreSQL + `pgvector` schema, Storage RLS, and `auth.users` profile sync trigger
- [x] Multimodal PDF CV extraction (`cv-parse`) and timeline profile UI
- [x] JWT-authenticated Edge Functions (`chat-proxy`, `cv-parse`) & secret-guarded `ingest`
- [x] Automated GitHub Actions release APK pipeline (Gradle 9.5.1 / AGP 9.1.1)
- [ ] **Application Funnel (`Saved` → `Draft` → `Applied`):** Dedicated `tailor-cv` Edge Function + selectable-text A4 PDF export for job-tailored CVs and cover letters
- [ ] **Context-Aware Career Assistant:** Inject candidate profile snapshot + top visible ranked jobs into `chat-proxy` with prompt-injection delimiters
- [ ] **Hybrid Vector Search (`pgvector` + `tsvector` RRF):** Populate `vector(1536)` embeddings via `gemini-embedding-001` and move ranking from client lexical scoring to a server-side PostgreSQL RPC
- [ ] **Real-Time SSE Chat Streaming:** Upgrade `chat-proxy` and `ChatNotifier` to stream tokens via `:streamGenerateContent?alt=sse`
- [ ] **Regional APAC / Indonesia Job Adapters:** Expand `ingest` with `Remotive`, `Adzuna`, and `JSearch` adapters + automated 6-hour `pg_