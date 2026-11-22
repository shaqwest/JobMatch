const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MODELS = ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-2.5-flash"];

async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs = 15000) {
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

async function generateChatReply(apiKey: string, systemPrompt: string, userMessage: string): Promise<string> {
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
            contents: [{ role: "user", parts: [{ text: userMessage }] }],
            generationConfig: {
              temperature: 0.4,
              maxOutputTokens: 1024,
            },
          }),
        },
        15000,
      );

      if (res.ok) {
        const data = await res.json();
        const text = extractAnswerText(data);
        if (text) return text;
        lastErr = `${model} returned empty text`;
        continue;
      }

      const errBody = await res.text();
      const hint = migrateHint(errBody);
      if (hint && !queue.includes(hint)) queue.push(hint);
      console.error(`[chat-proxy] ${model} HTTP ${res.status}: ${errBody.slice(0, 300)}`);
      lastErr = `${model} (${res.status})`;

      if (res.status === 503) {
        await new Promise((r) => setTimeout(r, 800));
      }
    } catch (e) {
      console.error(`[chat-proxy] ${model} exception:`, e);
      lastErr = `${model}: ${e}`;
    }
  }

  throw new Error(lastErr || "All Gemini models failed");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const apiKey = Deno.env.get("GOOGLE_API_KEY") ?? Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ reply: "Server configuration missing: set GOOGLE_API_KEY in Supabase Edge Function Secrets." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const { message } = await req.json().catch(() => ({ message: "" }));
  const cleanMessage = String(message ?? "")
    .replace(/<system-reminder>[\s\S]*?<\/system-reminder>/gi, "")
    .trim();

  if (!cleanMessage) {
    return new Response(
      JSON.stringify({ reply: "Please enter a message." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const sysPrompt = [
    "You are JobMatch, a concise career assistant for software engineers and tech professionals in Indonesia.",
    "Help with job search strategy, CV optimization, and interview prep.",
    "Keep responses practical, friendly, and concise (2-4 short sentences unless asked for detail).",
  ].join(" ");

  try {
    const reply = await generateChatReply(apiKey, sysPrompt, cleanMessage);
    return new Response(
      JSON.stringify({ reply }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ reply: `AI temporarily unavailable (${err.message}). Please try again in a moment.` }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});