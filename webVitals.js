const metricNames = new Set(["CLS", "INP", "LCP"]);

function enviarMetrica(metric) {
  if (!metricNames.has(metric.name) || !Number.isFinite(metric.value)) return;
  const payload = JSON.stringify({
    name: metric.name,
    value: Math.round(metric.value * 100) / 100,
    rating: metric.rating,
    delta: Math.round(metric.delta * 100) / 100,
    id: String(metric.id).slice(0, 80),
    path: window.location.pathname.slice(0, 160)
  });
  const body = new Blob([payload], { type: "application/json" });
  if (!navigator.sendBeacon("/api/web-vitals", body)) {
    fetch("/api/web-vitals", { method: "POST", body, keepalive: true }).catch(() => {});
  }
}

export async function iniciarWebVitals() {
  if (navigator.doNotTrack === "1" || window.__mgWebVitalsStarted) return;
  window.__mgWebVitalsStarted = true;
  try {
    const { onCLS, onINP, onLCP } = await import("https://esm.sh/web-vitals@4.2.4");
    onCLS(enviarMetrica);
    onINP(enviarMetrica);
    onLCP(enviarMetrica);
  } catch (error) {
    console.warn("Web Vitals indisponível:", error.message);
  }
}
