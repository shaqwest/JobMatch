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
        body: JSON.stringify({ contents: [{ parts: [{ text }] }], generationConfig: { temperature: 0.4, maxOutputTokens: 600 } }),
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

async function fetchWithTimeout(url: string, options: any, timeout = 10000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(id);
    return response;
  } catch (e) {
    clearTimeout(id);
    throw e;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const { message } = await req.json().catch(() => ({ message: "" }));
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) {
    return new Response(JSON.stringify({ reply: "Demo mode: set NINE_ROUTER_API_KEY in Supabase Vault to enable AI." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  function sanitize(text: string): string {
    let t = text.trim();
    t = t.replace(/```[\s\S]*?```/g, "").trim();
    t = t.replace(/^\s*```.*$/gm, "").trim();
    const leakRe = /(role\s*:|constraint\s*:|persona\s*:|option\s*\d|user\s*says\s*:|be concise|acknowledge greeting|state purpose)/i;
    let lines = t.split("\n");
    const hasLeak = lines.some((l) => leakRe.test(l));
    if (hasLeak) {
      lines = lines.filter((l) => !leakRe.test(l));
      lines = lines.filter((l) => {
        const low = l.trim().toLowerCase();
        if (!low) return false;
        if (/^[\*\-\•]\s*(role|constraint|persona|option|style|input|capa)/i.test(low)) return false;
        return true;
      });
      t = lines.join("\n").trim();
      const quoted = t.match(/"([^"]{10,})"/);
      if (quoted && !leakRe.test(quoted[1])) t = quoted[1];
    } else {
      t = lines.filter((l) => {
        const low = l.trim().toLowerCase();
        if (/^[\*\-\•]\s*(role|constraint|persona|option)/i.test(low)) return false;
        return true;
      }).join("\n").trim();
    }
    if (t.startsWith('"') && t.endsWith('"') && t.length > 2) t = t.slice(1, -1).trim();
    t = t.replace(/\*\*([^*]+)\*\*/g, "$1").trim();
    t = t.replace(/^\s*[\*\-\•]\s+/gm, "").trim();
    return t.trim();
  }

  try {
    const sysPrompt = "You are JobMatch, a helpful AI career assistant. Your purpose is to assist users with job searches, CV optimization, and interview preparation. Output ONLY the response meant for the user. Do not include internal thoughts, reasoning steps, or prompt tags like 'User says:' or 'Role:'. Keep your answers natural, friendly, and concise (1-3 sentences unless asked for details).";
    const base = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");
    const url = `${base}/chat/completions`;
    // Reduced to 2 most reliable models for faster failover
    const openModels = ["gemini-2.0-flash", "gemini-1.5-flash"];
    let reply = "";
    let lastError = "";
    for (const model of openModels) {
      try {
        const r = await fetchWithTimeout(url, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
          body: JSON.stringify({
            model,
            messages: [
              { role: "system", content: sysPrompt },
              { role: "user", content: message },
            ],
            temperature: 0.4,
            max_tokens: 600,
          }),
        }, 12000); // 12s timeout per attempt
        if (r.ok) {
          const jr = await r.json();
          let text: string = jr.choices?.[0]?.message?.content ?? jr.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          if (text) { text = sanitize(text); if (text) { reply = text; break; } }
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
      console.log("OpenAI compat yielded no reply, trying direct native fallback...");
      const fallbackModel = "gemini-1.5-flash";
      try {
        let text = await nativeGenerate(key, `${sysPrompt}\n\nUser: ${message}`, fallbackModel);
        if (text) {
          text = sanitize(text);
          if (text) reply = text;
        }
      } catch (e) {
        console.error(`Fallback failed: ${e}`);
      }
    }
    if (!reply) reply = lastError ? `AI Error: ${lastError}` : "No reply received from AI.";
    else reply = sanitize(reply);
    return new Response(JSON.stringify({ reply }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err: any) {
    console.error("Exception:", err);
    return new Response(JSON.stringify({ reply: `Error connecting to AI: ${err.message}` }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
