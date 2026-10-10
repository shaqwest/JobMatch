const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function extractPdfText(bytes: Uint8Array): string {
  const raw = new TextDecoder("utf-8", { fatal: false }).decode(bytes);
  const parts: string[] = [];
  const parenRe = /\(([^\)]{2,500})\)\s*Tj/g;
  let m: RegExpExecArray | null;
  while ((m = parenRe.exec(raw)) !== null) {
    const s = m[1].replace(/\\\(/g, "(").replace(/\\\)/g, ")").replace(/\\n/g, " ").replace(/\\\\/g, "\\");
    if (s.trim().length > 1) parts.push(s);
  }
  const tjArrayRe = /\[([^\]]{10,2000})\]\s*TJ/g;
  while ((m = tjArrayRe.exec(raw)) !== null) {
    const inside = m[1];
    const strRe = /\(([^\)]+)\)/g;
    let sm: RegExpExecArray | null;
    while ((sm = strRe.exec(inside)) !== null) {
      const s = sm[1].replace(/\\\(/g, "(").replace(/\\\)/g, ")");
      if (s.trim().length > 1) parts.push(s);
    }
  }
  const hexRe = /<([0-9A-Fa-f]{4,})>\s*Tj/g;
  while ((m = hexRe.exec(raw)) !== null) {
    try {
      const hex = m[1].replace(/\s/g, "");
      let decoded = "";
      for (let i = 0; i < hex.length; i += 4) {
        const code = parseInt(hex.slice(i, i + 4), 16);
        if (code > 31) decoded += String.fromCharCode(code);
        else decoded += " ";
      }
      if (decoded.trim().length > 2) parts.push(decoded);
    } catch (_) {}
  }
  let text = parts.join(" ").replace(/\s+/g, " ").trim();
  if (text.length < 80) {
    const fallback = raw.replace(/[^\x20-\x7E\n]/g, " ").replace(/\s+/g, " ").trim();
    const words = fallback.split(" ").filter((w) => w.length >= 2 && /[a-zA-Z]/.test(w));
    if (words.length > 30) text = words.slice(0, 1200).join(" ");
  }
  return text.slice(0, 8000);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  let path = "";
  try {
    const body = await req.json();
    path = body.path ?? "";
  } catch (_) {}
  if (!path) {
    return new Response(JSON.stringify({ error: "missing path" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) {
    return new Response(JSON.stringify({ error: "NINE_ROUTER_API_KEY not set in Edge Function secrets" }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ error: "SUPABASE_URL or SERVICE_ROLE_KEY not set" }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  const fileRes = await fetch(`${supabaseUrl}/storage/v1/object/cv_pdfs/${path}`, {
    headers: { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
  });
  if (!fileRes.ok) {
    const t = await fileRes.text().catch(() => "");
    return new Response(JSON.stringify({ error: `cannot fetch pdf (${fileRes.status}): ${t.slice(0, 300)}` }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  const bytes = new Uint8Array(await fileRes.arrayBuffer());
  if (bytes.length < 10) {
    return new Response(JSON.stringify({ error: "pdf empty" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  let pdfText = extractPdfText(bytes);
  if (pdfText.length < 20) pdfText = "(no extractable text — PDF may be scanned image)";

  const systemPrompt = `You are a CV parser. Extract fields from the CV text below and return JSON ONLY with keys: full_name,email,phone,location,summary,skills(array of strings),experience(string, concise 2-4 lines),education(string, concise). Use empty string or [] if not found. Do not add markdown.`;

  const base = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");
  const r = await fetch(`${base}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: "gemini-2.0-flash",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: `CV text:\n${pdfText}` },
      ],
      temperature: 0.1,
    }),
  });
  if (!r.ok) {
    const t = await r.text();
    const short = t.includes("<!DOCTYPE") ? `HTTP ${r.status}` : t.slice(0, 600);
    return new Response(JSON.stringify({ error: `AI error ${r.status}: ${short}` }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  const jr = await r.json();
  const content = jr.choices?.[0]?.message?.content ?? "{}";
  const m = content.match(/\{[\s\S]*\}/);
  let parsed: Record<string, unknown> = {};
  try {
    parsed = m ? JSON.parse(m[0]) : {};
  } catch (_) {
    parsed = { _raw: content.slice(0, 1000) };
  }
  return new Response(JSON.stringify(parsed), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
});
