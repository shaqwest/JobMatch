const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function discoverModels(key: string): Promise<string[]> {
  for (const ver of ["v1beta", "v1"]) {
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/${ver}/models?key=${key}`);
      if (!r.ok) continue;
      const j = await r.json();
      const models: any[] = j.models ?? [];
      const flash = models
        .filter((m: any) => (m.supportedGenerationMethods ?? []).includes("generateContent"))
        .map((m: any) => (m.name ?? "").replace("models/", ""))
        .filter((n: string) => n && !n.includes("embedding") && !n.includes("image") && !n.includes("veo") && !n.includes("tts"));
      flash.sort((a: string, b: string) => {
        const rank = (s: string) => (s.includes("2.5") ? 3 : s.includes("2.0") ? 2 : s.includes("1.5") ? 1 : 0);
        return rank(b) - rank(a);
      });
      if (flash.length) return flash;
    } catch (_) {}
  }
  return [];
}

async function nativeGenerate(key: string, text: string, model: string): Promise<string> {
  for (const ver of ["v1beta", "v1"]) {
    try {
      const url = `https://generativelanguage.googleapis.com/${ver}/models/${model}:generateContent?key=${key}`;
      const r = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents: [{ parts: [{ text }] }] }),
      });
      if (!r.ok) {
        const t = await r.text();
        console.error(`Native ${model} ${ver} ${r.status}: ${t.slice(0, 300)}`);
        continue;
      }
      const jr = await r.json();
      const out = jr.candidates?.[0]?.content?.parts?.[0]?.text;
      if (out) return out;
    } catch (e) {
      console.error(`Native ${model} exception: ${e}`);
    }
  }
  return "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const { message } = await req.json().catch(() => ({ message: "" }));
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) {
    return new Response(JSON.stringify({ reply: "Demo mode: set NINE_ROUTER_API_KEY in Supabase Vault to enable AI." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  try {
    const base = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");
    const url = `${base}/chat/completions`;
    const openModels = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-2.0-flash-exp", "gemini-3-flash-preview"];
    let reply = "";
    let lastError = "";
    for (const model of openModels) {
      try {
        const r = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
          body: JSON.stringify({
            model,
            messages: [
              { role: "system", content: "You are JobMatch assistant. Help with job search, CV, and interview prep. Be concise and professional." },
              { role: "user", content: message },
            ],
            temperature: 0.6,
          }),
        });
        if (r.ok) {
          const jr = await r.json();
          const text = jr.choices?.[0]?.message?.content ?? jr.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          if (text) { reply = text; break; }
          lastError = `OpenAI ${model} 200 no text: ${JSON.stringify(jr).slice(0, 200)}`;
        } else {
          const t = await r.text();
          lastError = t.includes("<!DOCTYPE") ? `HTTP ${r.status} at ${url}` : t.slice(0, 400);
        }
      } catch (e) {
        lastError = `${e}`.slice(0, 400);
      }
    }
    if (!reply) {
      console.log("OpenAI compat yielded no reply, discovering native models...");
      const discovered = await discoverModels(key);
      const candidates = discovered.length ? discovered : ["gemini-2.5-flash", "gemini-1.5-flash-latest", "gemini-1.5-pro", "gemini-pro", "gemini-2.0-flash-exp"];
      const prompt = `You are JobMatch assistant. Help with job search, CV, and interview prep. Be concise.\n\nUser: ${message}`;
      for (const m of candidates) {
        const text = await nativeGenerate(key, prompt, m);
        if (text) { reply = text; console.log(`Native success with ${m}`); break; }
      }
    }
    if (!reply) reply = lastError ? `AI Error: ${lastError}` : "No reply received from AI.";
    return new Response(JSON.stringify({ reply }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err: any) {
    console.error("Exception:", err);
    return new Response(JSON.stringify({ reply: `Error connecting to AI: ${err.message}` }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
