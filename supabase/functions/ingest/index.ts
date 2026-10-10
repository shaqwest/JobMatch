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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  const baseUrl = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");
  const NINE_ROUTER_URL = `${baseUrl}/chat/completions`;
  
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
        const resp = await fetch(NINE_ROUTER_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
          body: JSON.stringify({
            model: "gemini-2.0-flash",
            messages: [{ role: "user", content: `Extract JSON only: {"type":"WFO|Remote|Hybrid","employment":"full_time|part_time|contract","contract_duration":null|string,"salary_min":null|int,"salary_max":null|int,"benefits":null|string,"responsibilities":string,"workload":null|string} from: ${j.description.slice(0, 4000)}` }],
            temperature: 0.2,
          }),
        });
        const jr = await resp.json();
        const content = jr.choices?.[0]?.message?.content ?? "";
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
