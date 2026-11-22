import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const MODELS = ["gemini-3.5-flash-lite", "gemini-2.5-flash", "gemini-3.8-flash"];

async function fetchWithTimeout(url: string, options: RequestInit = {}, timeoutMs = 15000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(id);
  }
}

function toIsoTimestamp(raw: unknown): string {
  if (typeof raw === "number") {
    const ms = raw < 1e12 ? raw * 1000 : raw;
    return new Date(ms).toISOString();
  }
  if (typeof raw === "string" && raw.trim()) {
    const parsed = Date.parse(raw);
    if (!Number.isNaN(parsed)) return new Date(parsed).toISOString();
  }
  return new Date().toISOString();
}

async function fetchArbeitnow(): Promise<any[]> {
  const r = await fetchWithTimeout("https://www.arbeitnow.com/api/job-board-api", {}, 12000);
  if (!r.ok) return [];
  const j = await r.json();
  return (j.data ?? [])
    .slice(0, 25)
    .map((x: any) => ({
      title: String(x.title ?? "Untitled Role"),
      company: String(x.company_name ?? "Unknown Company"),
      location: String(x.location ?? "Remote"),
      type: x.remote ? "Remote" : "WFO",
      employment: "full_time",
      posted_at: toIsoTimestamp(x.created_at),
      source: "arbeitnow",
      description: String(x.description ?? x.title ?? "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim(),
      apply_url: String(x.url ?? ""),
      website: null,
    }))
    .filter((j: any) => j.apply_url.startsWith("http"));
}

async function normalizeWithGemini(apiKey: string, description: string): Promise<Record<string, any> | null> {
  const prompt = `Extract job metadata as JSON ONLY with keys:
{"type":"WFO|Remote|Hybrid","employment":"full_time|part_time|contract","contract_duration":null,"salary_min":null,"salary_max":null,"benefits":null,"responsibilities":"concise summary","workload":null}
Job description:
${description.slice(0, 3500)}`;

  for (const model of MODELS) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const r = await fetchWithTimeout(
        url,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 1024,
              responseMimeType: "application/json",
            },
          }),
        },
        15000,
      );
      if (!r.ok) continue;
      const jr = await r.json();
      const parts: any[] = jr?.candidates?.[0]?.content?.parts ?? [];
      const text = parts.filter((p) => !p?.thought && typeof p?.text === "string").map((p) => p.text).join("").trim();
      const m = text.match(/\{[\s\S]*\}/);
      if (m) return JSON.parse(m[0]);
    } catch (_) {}
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const cronSecret = Deno.env.get("CRON_SECRET");
  const providedCron = req.headers.get("x-cron-secret");
  const authHeader = req.headers.get("Authorization");

  const isServiceRole = Boolean(serviceKey && authHeader === `Bearer ${serviceKey}`);
  const isValidCron = Boolean(cronSecret && providedCron === cronSecret);

  if (!isServiceRole && !isValidCron) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const apiKey = Deno.env.get("GOOGLE_API_KEY") ?? Deno.env.get("GEMINI_API_KEY");

  let jobs: any[] = [];
  try {
    jobs = await fetchArbeitnow();
  } catch (e) {
    console.error("[ingest] fetchArbeitnow failed:", e);
  }

  let inserted = 0;
  for (const j of jobs) {
    const { data: existing } = await supabase
      .from("jobs")
      .select("id")
      .eq("apply_url", j.apply_url)
      .maybeSingle();

    if (existing) continue;

    let normalized = j;
    if (apiKey) {
      const aiFields = await normalizeWithGemini(apiKey, j.description);
      if (aiFields) normalized = { ...j, ...aiFields };
    }

    const { error } = await supabase.from("jobs").upsert(
      {
        title: normalized.title,
        company: normalized.company,
        location: normalized.location,
        type: ["WFO", "Remote", "Hybrid"].includes(normalized.type) ? normalized.type : j.type,
        employment: ["full_time", "part_time", "contract"].includes(normalized.employment)
          ? normalized.employment
          : "full_time",
        contract_duration: normalized.contract_duration ?? null,
        salary_min: Number.isInteger(normalized.salary_min) ? normalized.salary_min : null,
        salary_max: Number.isInteger(normalized.salary_max) ? normalized.salary_max : null,
        posted_at: normalized.posted_at,
        source: normalized.source,
        description: normalized.description,
        responsibilities: normalized.responsibilities ?? null,
        benefits: normalized.benefits ?? null,
        workload: normalized.workload ?? null,
        apply_url: normalized.apply_url,
        website: normalized.website ?? null,
      },
      { onConflict: "apply_url", ignoreDuplicates: true },
    );

    if (!error) inserted++;
  }

  return new Response(
    JSON.stringify({ fetched: jobs.length, inserted }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});