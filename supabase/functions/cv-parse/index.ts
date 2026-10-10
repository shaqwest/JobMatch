const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const { path } = await req.json().catch(() => ({ path: "" }));
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) {
    return new Response(JSON.stringify({ error: "NINE_ROUTER_API_KEY not set" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    return new Response(JSON.stringify({ error: "SUPABASE_SERVICE_ROLE_KEY not set" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const fileRes = await fetch(`${supabaseUrl}/storage/v1/object/cv_pdfs/${path}`, {
    headers: { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
  });
  if (!fileRes.ok) {
    return new Response(JSON.stringify({ error: "cannot fetch pdf" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const hint = `You are a CV parser. Return JSON only with keys: full_name,email,phone,location,summary,skills(array),experience(string),education(string). From the PDF at storage path ${path} — if text unavailable, return empty strings.`;
  const r = await fetch("https://api.9router.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({ model: "gemini-2.0-flash", messages: [{ role: "user", content: hint }], temperature: 0.1 }),
  });
  if (!r.ok) {
    const t = await r.text();
    return new Response(JSON.stringify({ error: `AI error ${r.status}: ${t}` }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const jr = await r.json();
  const content = jr.choices?.[0]?.message?.content ?? "{}";
  const m = content.match(/\{[\s\S]*\}/);
  const parsed = m ? JSON.parse(m[0]) : {};
  return new Response(JSON.stringify(parsed), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
