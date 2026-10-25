import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

const root = process.cwd();
const failures = [];

async function filesIn(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = await Promise.all(entries.map(async entry => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      if ([".git", "node_modules", "evidencias", "backups"].includes(entry.name)) return [];
      return filesIn(path);
    }
    return [path];
  }));
  return files.flat();
}

const files = await filesIn(root);
const htmlFiles = files.filter(path => path.endsWith(".html"));

for (const path of htmlFiles) {
  const html = await readFile(path, "utf8");
  const relative = path.slice(root.length + 1);
  const h1Count = (html.match(/<h1[\s>]/gi) || []).length;
  const h1Allowed = relative === "index.html" || relative === "MG-MARKETPLACE/anuncio.html";

  if (!h1Allowed && h1Count !== 1) failures.push(`${relative}: esperado exatamente um <h1>, encontrado ${h1Count}`);
  if (/lucide@latest/i.test(html)) failures.push(`${relative}: Lucide não está fixado em uma versão`);
  if (/target="_blank"(?![^>]*\brel=)/i.test(html)) failures.push(`${relative}: link externo sem rel="noopener"`);
}

const requiredFiles = ["robots.txt", "sitemap.xml", "supabase/tests/rls-security-check.sh"];
for (const relative of requiredFiles) {
  if (!files.some(path => path.slice(root.length + 1) === relative)) failures.push(`arquivo obrigatório ausente: ${relative}`);
}

const rlsScript = await readFile(join(root, "supabase/tests/rls-security-check.sh"), "utf8");
if (/SUPABASE_URL:-https?:\/\//.test(rlsScript) || /SUPABASE_ANON_KEY:-sb_publishable/.test(rlsScript)) {
  failures.push("o roteiro RLS não pode ter URL ou chave padrão");
}
if (!/ALLOW_DESTRUCTIVE_PROBES/.test(rlsScript) || !/CONFIRM_STAGING/.test(rlsScript)) {
  failures.push("o roteiro RLS precisa exigir confirmação explícita para sondas destrutivas");
}
if (!/ilswwmjojfuvcgyymymb/.test(rlsScript)) {
  failures.push("o roteiro RLS precisa bloquear explicitamente o projeto de produção");
}

const securityMigration = await readFile(join(root, "supabase/migrations/20261020120000_security_hardening.sql"), "utf8");
for (const fragment of [
  'CREATE POLICY "usuarios insert proprio"',
  'coalesce(is_admin, false) = false',
  'proteger_campos_sensiveis_usuarios_insert',
  'usuarios_id_auth_fkey',
]) {
  if (!securityMigration.includes(fragment)) failures.push(`hardening RLS ausente: ${fragment}`);
}

const devPanel = await readFile(join(root, "MG-DEV/devpanel.html"), "utf8");
if (!/db\.rpc\(['"]is_admin['"]\)/.test(devPanel) || !/if \(!admin\)/.test(devPanel)) {
  failures.push("painel administrativo precisa autorizar pelo RPC is_admin()");
}
if (/ADMIN_EMAILS|value\s*=\s*["'][^"']+@/i.test(devPanel)) {
  failures.push("painel administrativo não pode expor ou pré-preencher e-mail de administrador");
}

const globalCss = await readFile(join(root, "global.css"), "utf8");
const globalHeader = await readFile(join(root, "headerGlobal.js"), "utf8");
if (/\.mg-toast-?icon::before\s*\{\s*content:\s*["'](?:✅|❌|ℹ️|⚠️)/.test(globalCss)) {
  failures.push("toasts globais não podem usar emojis como ícones");
}
for (const icon of ["circle-check", "circle-alert", "info", "triangle-alert"]) {
  if (!globalHeader.includes(`'${icon}'`)) failures.push(`toast global sem ícone Lucide: ${icon}`);
}

const vercelConfig = JSON.parse(await readFile(join(root, "vercel.json"), "utf8"));
const csp = vercelConfig.headers?.flatMap(group => group.headers || [])
  .find(header => header.key === "Content-Security-Policy")?.value || "";
for (const origin of ["https://esm.sh", "https://nominatim.openstreetmap.org"]) {
  if (!csp.includes(origin)) failures.push(`CSP não permite o recurso externo usado: ${origin}`);
}

if (failures.length) {
  console.error("Validação estática falhou:");
  failures.forEach(failure => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(`Validação estática aprovada para ${htmlFiles.length} páginas.`);
