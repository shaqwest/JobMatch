const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function callGoogleNative(key: string, message: string): Promise<string> {
  const models = ["gemini-2.0-flash", "gemini-1.5-flash"];
  for (const model of models) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
      const r = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `You are JobMatch assistant. Help with job search, CV, and interview prep. Be concise.\n\nUser: ${message}` }] }],
        }),
      });
      if (!r.ok) {
        const t = await r.text();
        console.error(`Native Gemini ${model} failed (${r.status}): ${t.slice(0, 300)}`);
        continue;
      }
      const jr = await r.json();
      const text = jr.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text) return text;
    } catch (e) {
      console.error(`Native Gemini ${model} exception: ${e}`);
    }
  }
  return "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const { message } = await req.json().catch(() => ({ message: "" }));
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) {
    return new Response(
      JSON.stringify({ reply: "Demo mode: set NINE_ROUTER_API_KEY in Supabase Vault to enable AI." }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const base = (Deno.env.get("NINE_ROUTER_BASE_URL") ?? "https://generativelanguage.googleapis.com/v1beta/openai").replace(/\/$/, "");
    const url = `${base}/chat/completions`;
    const models = ["gemini-2.0-flash", "gemini-1.5-flash"];
    let reply = "";
    let lastError = "";

    // Strategy 1: OpenAI-compatible endpoint
    for (const model of models) {
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
          console.log("OpenAI endpoint raw JSON:", JSON.stringify(jr).slice(0, 400));
          reply =
            jr.choices?.[0]?.message?.content ??
            jr.candidates?.[0]?.content?.parts?.[0]?.text ??
            "";
          if (reply) break;
          lastError = `OpenAI endpoint returned 200 but no text content in JSON: ${JSON.stringify(jr).slice(0, 200)}`;
        } else {
          const t = await r.text();
          const short = t.includes("<!DOCTYPE") ? `HTTP ${r.status} at ${url}` : t.slice(0, 400);
          lastError = short;
        }
      } catch (e) {
        lastError = `${e}`.slice(0, 400);
      }
    }

    // Strategy 2: Native Google generateContent API fallback if Strategy 1 yielded no text
    if (!reply) {
      console.log("OpenAI compat yielded no reply, attempting Native Google generateContent fallback...");
      reply = await callGoogleNative(key, message);
    }

    if (!reply) {
      reply = lastError ? `AI Error: ${lastError}` : "No reply received from AI.";
    }
    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("Exception:", err);
    return new Response(JSON.stringify({ reply: `Error connecting to AI: ${err.message}` }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
