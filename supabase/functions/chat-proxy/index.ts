const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
    const models = ["gemini-2.0-flash", "gemini-2.5-flash"];
    let reply = "";
    let lastError = "";

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
          reply = jr.choices?.[0]?.message?.content ?? "";
          if (reply) break;
        } else {
          const t = await r.text();
          const short = t.includes("<!DOCTYPE") ? `HTTP ${r.status} at ${url}` : t.slice(0, 400);
          lastError = short;
        }
      } catch (e) {
        lastError = `${e}`.slice(0, 400);
      }
    }

    if (!reply) {
      reply = lastError ? `AI Error: ${lastError}` : "No reply received from AI.";
    }
    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Exception:", err);
    return new Response(JSON.stringify({ reply: `Error connecting to AI: ${err.message}` }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
