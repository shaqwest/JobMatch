const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MODELS = ["gemini-3.5-flash-lite", "gemini-2.5-flash", "gemini-3.8-flash"];

function uint8ToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs = 45000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(id);
  }
}

function extractAnswerText(json: any): string {
  const parts: any[] = json?.candidates?.[0]?.content?.parts ?? [];
  return parts
    .filter((p) => !p?.thought && typeof p?.text === "string")
    .map((p) => p.text)
    .join("")
    .trim();
}

function migrateHint(body: string): string | null {
  const m = body.match(/models\/([a-z0-9.\-_]+)/i);
  if (m && body.toLowerCase().includes("please update")) return m[1];
  return null;
}

async function parsePdfWithGemini(apiKey: string, systemPrompt: string, pdfBase64: string): Promise<string> {
  const queue = [...MODELS];
  let lastErr = "";

  for (const model of queue) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const res = await fetchWithTimeout(
        url,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: systemPrompt }] },
            contents: [
              {
                role: "user",
                parts: [
                  { inlineData: { mimeType: "application/pdf", data: pdfBase64 } },
                  { text: "Parse this resume PDF into the requested JSON structure." },
                ],
              },
            ],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 4096,
              responseMimeType: "application/json",
            },
          }),
        },
        45000,
      );

      if (res.ok) {
        const data = await res.json();
        const text = extractAnswerText(data);
        if (text) return text;
        lastErr = `${model} returned empty JSON`;
        continue;
      }

      const errBody = await res.text();
      const hint = migrateHint(errBody);
      if (hint && !queue.includes(hint)) queue.push(hint);
      console.error(`[cv-parse] ${model} HTTP ${res.status}: ${errBody.slice(0, 300)}`);
      lastErr = `${model} (${res.status})`;

      if (res.status === 503) {
        await new Promise((r) => setTimeout(r, 1000));
      }
    } catch (e) {
      console.error(`[cv-parse] ${model} exception:`, e);
      lastErr = `${model}: ${e}`;
    }
  }

  throw new Error(lastErr || "All Gemini models failed during CV parse");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  let path = "";
  try {
    const body = await req.json();
    path = String(body.path ?? "").trim();
  } catch (_) {}

  if (!path) {
    return new Response(JSON.stringify({ error: "missing path" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const apiKey = Deno.env.get("GOOGLE_API_KEY") ?? Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "GOOGLE_API_KEY not set in Edge Function secrets" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ error: "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const fileRes = await fetch(`${supabaseUrl}/storage/v1/object/cv_pdfs/${path}`, {
    headers: { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
  });
  if (!fileRes.ok) {
    const errText = await fileRes.text().catch(() => "");
    return new Response(
      JSON.stringify({ error: `Cannot fetch PDF (${fileRes.status}): ${errText.slice(0, 200)}` }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const bytes = new Uint8Array(await fileRes.arrayBuffer());
  if (bytes.length < 10) {
    return new Response(JSON.stringify({ error: "Uploaded PDF is empty" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const systemPrompt = `You are an expert technical CV parser. Extract candidate details from the attached PDF and return valid JSON ONLY with these exact keys:
{
  "full_name": "string",
  "email": "string",
  "phone": "string",
  "location": "string",
  "headline": "short professional title, e.g. Mobile Engineer | Flutter",
  "summary": "1-2 sentence summary",
  "skills": ["skill1", "skill2"],
  "experience": [
    {
      "id": "1",
      "company": "string",
      "title": "string",
      "duration": "string",
      "points": ["achievement 1", "achievement 2"],
      "is_current": false
    }
  ],
  "education": "concise string"
}
Use "" or [] when a field is missing. Never fabricate employers or skills.`;

  try {
    const pdfBase64 = uint8ToBase64(bytes);
    const rawJson = await parsePdfWithGemini(apiKey, systemPrompt, pdfBase64);
    const match = rawJson.match(/\{[\s\S]*\}/);
    const parsed: Record<string, any> = match ? JSON.parse(match[0]) : JSON.parse(rawJson);

    const parts = path.split("/");
    const userId = parts[0];
    const fileName = parts.slice(1).join("/") || null;

    if (userId) {
      const upsertPayload: Record<string, any> = {
        id: userId,
        cv_url: path,
        cv_filename: fileName,
        cv_parsed: parsed,
      };

      const scalarFields = ["full_name", "email", "phone", "location", "headline", "summary", "education"];
      for (const f of scalarFields) {
        if (typeof parsed[f] === "string" && parsed[f].trim().length > 0) {
          upsertPayload[f] = parsed[f].trim();
        }
      }
      if (Array.isArray(parsed.skills)) upsertPayload.skills = parsed.skills;
      if (Array.isArray(parsed.experience)) upsertPayload.experience = parsed.experience;

      const dbRes = await fetch(`${supabaseUrl}/rest/v1/profiles?on_conflict=id`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          Prefer: "resolution=merge-duplicates,return=minimal",
        },
        body: JSON.stringify(upsertPayload),
      });

      if (!dbRes.ok) {
        const dbErr = await dbRes.text();
        console.error(`[cv-parse] DB upsert failed (${dbRes.status}): ${dbErr}`);
      }
    }

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[cv-parse] Error:", err);
    return new Response(JSON.stringify({ error: err.message ?? "CV parsing failed" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});