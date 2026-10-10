import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function fetchArbeitnow(): Promise<any[]> {
  const r = await fetch("https://www.arbeitnow.com/api/job-board-api");
  if (!r.ok) return [];
  const j = await r.json();
  return (j.data ?? []).slice(0, 30).map((x: any) => ({
    title: x.title,
    company: x.company_name,
    location: x.location ?? "Remote",
    type: x.remote ? "Remote" : "WFO",
    employment: "full_time",
    posted_at: new Date(x.created_at ?? Date.now()).toISOString(),
    source: "arbeitnow",
    description: x.description ?? x.title,
    apply_url: x.url,
    website: x.company_name,
  }));
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function nativeGenerate(key: string, text: string, model: string): Promise<string> {
  for (const ver of ["v1beta", "v1"]) {
    try {
      const url = `https://generativelanguage.googleapis.com/${ver}/models/${model}:generateContent?key=${key}`;
      const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ contents: [{ parts: [{ text }] }] }) });
      if (!r.ok) continue;
      const jr = await r.json();
      const out = jr.candidates?.[0]?.content?.parts?.[0]?.text;
      if (out) return out;
    } catch (_) {}
  }
  return "";
}

async function discoverModels(key: string): Promise<string[]> {
  for (const ver of ["v1beta", "v1"]) {
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/${ver}/models?key=${key}`);
      if (!r.ok) continue;
      const j = await r.json();
      const models: any[] = j.models ?? [];
      const flash = models.filter((m: any) => (m.supportedGenerationMethods ?? []).includes("generateContent")).map((m: any) => (m.name ?? "").replace("models/", "")).filter((n: string) => n && !n.includes("embedding") && !n.includes("image") && !n.includes("veo") && !n.includes("tts"));
      if (flash.length) return flash;
    } catch (_) {}
  }
  return [];
}

async function normalizeWithAI(key: string, base: string, description: string): Promise<string> {
  const prompt = `Extract JSON only: {"type":"WFO|Remote|Hybrid","employment":"full_time|part_time|contract","contract_duration":null|string,"salary_min":null|int,"salary_max":null|int,"benefits":null|string,"responsibilities":string,"workload":null|string} from: ${description.slice(0, 4000)}`;
  const url = `${base}/chat/completions`;
  for (const model of ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash"]) {
    try {
      const resp = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` }, body: JSON.stringify({ model, messages: [{ role: "user", content: prompt }], temperature: 0.2 }) });
      if (resp.ok) {
        const jr = await resp.json();
        const c = jr.choices?.[0]?.message?.content ?? jr.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
        if (c) return c;
      }
    } catch (_) {}
  }
  const discovered = await discoverModels(key);
  const fallback = discovered.length ? discovered : ["gemini-2.5-flash", "gemini-1.5-flash-latest", "gemini-pro"];
  for (const m of fallback) {
    const text = await nativeGenerate(key, prompt, m);
    if (text) return text;
  }
  return "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  const baseUrl = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");

  let jobs: any[] = [];
  try {
    const a = await fetchArbeitnow();
    jobs = a;
  } catch (_) {}
  for (const j of jobs) {
    const { data: existing } = await supabase.from("jobs").select("id").eq("apply_url", j.apply_url).maybeSingle();
    if (existing) continue;
    let normalized = j;
    if (key) {
      try {
        const content = await normalizeWithAI(key, baseUrl, j.description);
        const m = content.match(/\{[\s\S]*\}/);
        if (m) {
          const ex = JSON.parse(m[0]);
          normalized = { ...j, ...ex };
        }
      } catch (_) {}
    }
    await supabase.from("jobs").insert({
      title: normalized.title,
      company: normalized.company,
      location: normalized.location,
      type: ["WFO", "Remote", "Hybrid"].includes(normalized.type) ? normalized.type : "WFO",
      employment: ["full_time", "part_time", "contract"].includes(normalized.employment) ? normalized.employment : "full_time",
      contract_duration: normalized.contract_duration ?? null,
      salary_min: normalized.salary_min ?? null,
      salary_max: normalized.salary_max ?? null,
      posted_at: normalized.posted_at,
      source: normalized.source,
      description: normalized.description,
      responsibilities: normalized.responsibilities ?? null,
      benefits: normalized.benefits ?? null,
      workload: normalized.workload ?? null,
      apply_url: normalized.apply_url,
      website: normalized.website ?? null,
    });
  }
  return new Response(JSON.stringify({ ingested: jobs.length }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
