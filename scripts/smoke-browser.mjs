import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, normalize, extname } from "node:path";
import { chromium } from "@playwright/test";

const root = process.cwd();
const port = 4173;
const baseUrl = `http://127.0.0.1:${port}`;
const routes = [
  { path: "/MG-INICIO/inicio.html", title: /MG\s?Motors/i, h1: /Encontre seu próximo veículo|Encontre o carro dos seus .*sonhos/i },
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

async function carregarPagina(page, url) {
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 15000 });
  return {
    title: await page.title(),
    h1: await page.locator("h1").first().textContent(),
    hasMainContent: await page.locator("main, section").count() > 0,
  };
}

const server = createServer(serve);
await new Promise(resolve => server.listen(port, "127.0.0.1", resolve));

let failures = 0;
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROMIUM_BIN || "/usr/bin/chromium",
});
const context = await browser.newContext();
// O smoke valida disponibilidade local. Dependências externas são cobertas
// pelo E2E e não devem tornar esta verificação intermitente.
await context.route("https://**/*", route => route.abort());
const page = await context.newPage();
try {
  for (const route of routes) {
    const document = await carregarPagina(page, `${baseUrl}${route.path}`);
    const checks = [
      ["title", route.title.test(document.title)],
      ["h1", route.h1.test(document.h1 || "")],
      ["main content", document.hasMainContent],
    ];
    if (route.selector) checks.push([route.selector, await page.locator(route.selector).count() > 0]);
    const failed = checks.filter(([, ok]) => !ok).map(([name]) => name);
    if (failed.length) {
      failures++;
      console.error(`FAIL ${route.path}: ${failed.join(", ")}`);
    } else {
      console.log(`PASS ${route.path}`);
    }
  }
} finally {
  await browser.close();
  server.close();
}

if (failures) {
  console.error(`Smoke test falhou em ${failures} página(s).`);
  process.exit(1);
}
console.log(`Smoke test aprovado: ${routes.length} páginas públicas.`);
