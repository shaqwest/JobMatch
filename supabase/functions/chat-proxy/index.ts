Deno.serve(async (req) => {
  const { message } = await req.json().catch(() => ({ message: "" }));
  const key = Deno.env.get("NINE_ROUTER_API_KEY");
  if (!key) return new Response(JSON.stringify({ reply: "Demo mode: set NINE_ROUTER_API_KEY in Supabase Vault to enable AI." }), { headers: { "Content-Type": "application/json" } });
  const r = await fetch("https://api.9router.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: "gemini-2.0-flash",
      messages: [
        { role: "system", content: "You are JobMatch assistant. Help with job search, CV, and interview prep. Be concise and professional." },
        { role: "user", content: message },
      ],
      temperature: 0.6,
    }),
  });
  const jr = await r.json();
  const reply = jr.choices?.[0]?.message?.content ?? "No reply";
  return new Response(JSON.stringify({ reply }), { headers: { "Content-Type": "application/json" } });
});
