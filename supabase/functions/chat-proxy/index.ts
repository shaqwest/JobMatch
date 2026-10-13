const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function fetchWithTimeout(url: string, options: any, timeout = 8000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeout);
  try {
    const r = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(id);
    return r;
  } catch (e) {
    clearTimeout(id);
    throw e;
  }
}

function migrateHint(body: string): string | null {
  const m = body.match(/models\/([a-z0-9.\-_]+)/i);
  if (m && body.toLowerCase().includes("please update")) return m[1];
  return null;
}

async function discoverModels(key: string): Promise<string[]> {
  for (const ver of ["v1beta", "v1"]) {
    try {
      const r = await fetchWithTimeout(`https://generativelanguage.googleapis.com/${ver}/models?key=${key}`, {}, 8000);
      if (!r.ok) continue;
      const j = await r.json();
      const models: any[] = j.models ?? [];
      let flash = models
        .filter((m: any) => (m.supportedGenerationMethods ?? []).includes("generateContent"))
        .map((m: any) => (m.name ?? "").replace("models/", ""))
        .filter((n: string) => n && !n.includes("embedding") && !n.includes("image") && !n.includes("veo") && !n.includes("tts"));
      flash = flash.filter((n: string) => !n.includes("computer-use") && !n.startsWith("gemma"));
      flash.sort((a: string, b: string) => {
        const rank = (s: string) => {
          if (s.includes("3.8")) return 10;
          if (s.includes("3.5")) return 9;
          if (s.includes("3.1")) return 8;
          if (s.includes("3.")) return 7;
          if (s.includes("2.5")) return 3;
          if (s.includes("2.0")) return 2;
          if (s.includes("1.5")) return 1;
          return 0;
        };
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
      const r = await fetchWithTimeout(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents: [{ parts: [{ text }] }], generationConfig: { temperature: 0.4, maxOutputTokens: 600 } }),
      }, 8000);
      if (!r.ok) {
        const t = await r.text();
        const hint = migrateHint(t);
        if (hint && hint !== model) {
          console.error(`Native ${model} ${ver} ${r.status} -> hint ${hint}`);
          try {
            const url2 = `https://generativelanguage.googleapis.com/${ver}/models/${hint}:generateContent?key=${key}`;
            const r2 = await fetchWithTimeout(url2, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ contents: [{ parts: [{ text }] }], generationConfig: { temperature: 0.4, maxOutputTokens: 600 } }),
            }, 8000);
            if (r2.ok) {
              const jr2 = await r2.json();
              const out2 = jr2.candidates?.[0]?.content?.parts?.[0]?.text;
              if (out2) return out2;
            } else {
              const t2 = await r2.text();
              console.error(`Native hint ${hint} ${ver} ${r2.status}: ${t2.slice(0, 300)}`);
            }
          } catch (e) {
            console.error(`Native hint ${hint} exception: ${e}`);
          }
        } else {
          console.error(`Native ${model} ${ver} ${r.status}: ${t.slice(0, 300)}`);
          if (r.status === 429) break;
        }
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
  // Strip system reminders from user input before processing
  const cleanMessage = (message ?? "").replace(/<system-reminder>[\s\S]*?<\/system-reminder>/gi, "").trim();
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) {
    return new Response(JSON.stringify({ reply: "Demo mode: set NINE_ROUTER_API_KEY in Supabase Vault to enable AI." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  function sanitize(text: string): string {
    let t = text.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/gi, "").trim();
    t = t.replace(/```[\s\S]*?```/g, "").trim();
    const lower = t.toLowerCase();
    const open = lower.lastIndexOf("<reply>");
    if (open !== -1) {
      let after = t.slice(open + 7);
      const close = after.toLowerCase().indexOf("</reply>");
      if (close !== -1) after = after.slice(0, close);
      after = after.trim().replace(/^["'\s]+|["'\s]+$/g, "").trim();
      if (after) return after;
    }
    const m = t.match(/<reply>([\s\S]*?)<\/reply>/i);
    if (m) return m[1].trim().replace(/^["'\s]+|["'\s]+$/g, "").trim();
    const leakRe = /(role\s*:|constraint\s*:|function\s*:|user input\s*:|draft\s*\d|concise\?|wrapped in|no reasoning|planning|output)/i;
    let lines = t.split("\n").filter((l) => {
      const s = l.replace(/^[\s*\-\•]+/, "").trim();
      if (!s) return false;
      if (leakRe.test(s)) return false;
      if (/^[\*\-\•]\s*(role|constraint|function|instruction|planning|output|user|draft|concise|wrapped|no reasoning)/i.test(s)) return false;
      return true;
    });
    t = lines.join("\n").trim();
    const quoted = t.match(/"([^"]{12,})"/);
    if (quoted && !leakRe.test(quoted[1])) return quoted[1].trim();
    if (t.startsWith('"') && t.endsWith('"')) t = t.slice(1, -1).trim();
    t = t.replace(/\*\*([^*]+)\*\*/g, "$1").trim();
    return t.trim();
  }

  try {
    const sysPrompt = `You are JobMatch, an expert career assistant. 
RULES:
1. Help with: job searches, CV optimization, interview preparation.
2. Be extremely concise (1-2 sentences).
3. If the user greets you, reply naturally.
4. You MUST wrap your final response to the user in <reply> tags.
5. Do NOT include reasoning, planning, or headers in your response.
Example: <reply>Hello! How can I help you today?</reply>`;
    const base = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");
    const url = `${base}/chat/completions`;
    const openModels = ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.1-pro-preview", "google/gemini-3.8-flash", "gemini-2.5-flash"];
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
              { role: "user", content: cleanMessage },
            ],
            temperature: 0.4,
            max_tokens: 600,
          }),
        }, 8000);
        if (r.ok) {
          const jr = await r.json();
          let text: string = jr.choices?.[0]?.message?.content ?? jr.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
          if (text) { text = sanitize(text); if (text) { reply = text; break; } }
          lastError = `OpenAI ${model} 200 no text: ${JSON.stringify(jr).slice(0, 200)}`;
        } else {
          const t = await r.text();
          const hint = migrateHint(t);
          lastError = hint ? `Model ${model} migrated to ${hint}: ${t.slice(0, 300)}` : t.slice(0, 400);
          console.error(`OpenAI ${model} ${r.status}: ${t.slice(0, 400)}`);
        }
      } catch (e) {
        lastError = `${e}`.slice(0, 400);
      }
    }
    if (!reply) {
      console.log("Compat proxy failed, trying native discovery...");
      const discovered = await discoverModels(key);
      let candidates = discovered.length ? discovered.slice(0, 3) : ["gemini-3.8-flash", "gemini-3.5-flash-lite"];
      for (const m of candidates) {
        let text = await nativeGenerate(key, `${sysPrompt}\n\nUser: ${cleanMessage}`, m);
        if (text) {
          text = sanitize(text);
          if (text) { reply = text; break; }
        }
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
