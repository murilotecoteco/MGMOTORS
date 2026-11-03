const ALLOWED_METRICS = new Set(["CLS", "INP", "LCP"]);

export default function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method not allowed" });
  }

  let body;
  try {
    body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : (req.body || {});
  } catch {
    return res.status(400).json({ error: "Invalid JSON" });
  }
  const value = Number(body.value);
  if (!ALLOWED_METRICS.has(body.name) || !Number.isFinite(value) || value < 0 || value > 1_000_000) {
    return res.status(400).json({ error: "Invalid metric" });
  }

  const event = {
    event: "web_vital",
    name: body.name,
    value: Math.round(value * 100) / 100,
    rating: typeof body.rating === "string" ? body.rating.slice(0, 16) : undefined,
    path: typeof body.path === "string" ? body.path.slice(0, 160) : "/"
  };
  console.log(JSON.stringify(event));
  return res.status(204).end();
}
