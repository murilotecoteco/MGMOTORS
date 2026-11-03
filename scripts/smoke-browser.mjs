import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, normalize, extname } from "node:path";
import { spawn } from "node:child_process";
import { promisify } from "node:util";

const root = process.cwd();
const chromium = process.env.CHROMIUM_BIN || "chromium";
const port = 4173;
const baseUrl = `http://127.0.0.1:${port}`;
const routes = [
  { path: "/MG-INICIO/inicio.html", title: /MG Motors/i, h1: /Encontre seu próximo veículo|Encontre o carro dos seus .*sonhos/i },
  { path: "/MG-MARKETPLACE/marketplace.html", title: /Marketplace/i, h1: /Encontre seu próximo veículo/i },
  { path: "/MG-DICAS/dicas.html", title: /Dicas/i, h1: /Dicas|segurança/i },
  { path: "/MG-CONTATO/contato.html", title: /Contato/i, h1: /excelência/i, selector: "#form-contato-site" },
  { path: "/MG-LOGIN/login.html", title: /Login|Entrar/i, h1: /Entrar|Acesse/i },
];

const mime = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".webp": "image/webp",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
};

function htmlDocument(output) {
  return output.replace(/<script[\s\S]*?<\/script>/gi, "").replace(/\s+/g, " ");
}

function serve(request, response) {
  const url = new URL(request.url, baseUrl);
  if (url.pathname === "/api/config") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({ supabaseUrl: "https://example.supabase.co", supabaseKey: "test-key" }));
    return;
  }

  const relative = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);
  const target = normalize(join(root, relative));
  if (!target.startsWith(root) || !existsSync(target)) {
    response.writeHead(404);
    response.end("Not found");
    return;
  }
  readFile(target).then(data => {
    response.writeHead(200, { "content-type": mime[extname(target)] || "application/octet-stream" });
    response.end(data);
  }).catch(() => {
    response.writeHead(500);
    response.end("Read error");
  });
}

function runChromium(url) {
  return new Promise((resolve, reject) => {
    const child = spawn(chromium, [
      "--headless", "--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage",
      "--no-first-run", "--no-default-browser-check", "--virtual-time-budget=2500",
      "--dump-dom", url,
    ], { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", chunk => { stdout += chunk; });
    child.stderr.on("data", chunk => { stderr += chunk; });
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error(`Chromium timeout em ${url}`));
    }, 20000);
    child.on("error", error => { clearTimeout(timer); reject(error); });
    child.on("close", code => {
      clearTimeout(timer);
      if (code !== 0) reject(new Error(`Chromium saiu com código ${code}: ${stderr.slice(-500)}`));
      else resolve(stdout);
    });
  });
}

const server = createServer(serve);
await new Promise(resolve => server.listen(port, "127.0.0.1", resolve));

let failures = 0;
try {
  for (const route of routes) {
    const output = htmlDocument(await runChromium(`${baseUrl}${route.path}`));
    const checks = [
      ["title", route.title.test(output)],
      ["h1", route.h1.test(output)],
      ["main content", /<(main|section)\b/i.test(output)],
    ];
    if (route.selector) checks.push([route.selector, new RegExp(`id=["']${route.selector.slice(1)}["']`, "i").test(output)]);
    const failed = checks.filter(([, ok]) => !ok).map(([name]) => name);
    if (failed.length) {
      failures++;
      console.error(`FAIL ${route.path}: ${failed.join(", ")}`);
    } else {
      console.log(`PASS ${route.path}`);
    }
  }
} finally {
  server.close();
}

if (failures) {
  console.error(`Smoke test falhou em ${failures} página(s).`);
  process.exit(1);
}
console.log(`Smoke test aprovado: ${routes.length} páginas públicas.`);
