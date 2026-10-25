// Auditoria de contraste WCAG 2.1 AA.
// Analisa rules CSS que declaram color e background no MESMO bloco
// (limitação conhecida: pares declarados em rules separadas não são
// detectados — o relatório é uma triagem, não uma verificação exaustiva).
//
// Uso: node scripts/a11y-contrast.mjs [caminho-do-css]
// Sem argumento, avalia global.css + todos os CSS das pastas MG-*/.
// Códigos de saída: 0 = sem violação severa, 1 = há violações a corrigir.

import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

const root = process.cwd();
const targetArg = process.argv[2];

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

let cssPaths;
if (targetArg) {
  cssPaths = [targetArg];
} else {
  const all = await filesIn(root);
  cssPaths = all.filter(p => p.endsWith(".css") && !p.includes("node_modules"));
}
cssPaths.sort();

const failSmall = [];
const failLarge = [];
let pairsChecked = 0;

function hexToRgb(hex) {
  let h = hex.replace("#", "").trim();
  if (h.length === 3) h = h.split("").map(c => c + c).join("");
  const n = parseInt(h, 16);
  if (Number.isNaN(n) || hex.length !== 4 && hex.length !== 7) return null;
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function srgbToLinear(channel) {
  const c = channel / 255;
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function luminance(hex) {
  const rgb = hexToRgb(hex);
  if (!rgb) return null;
  return 0.2126 * srgbToLinear(rgb[0]) + 0.7152 * srgbToLinear(rgb[1]) + 0.0722 * srgbToLinear(rgb[2]);
}

function relativeLuminance(fgHex, bgHex) {
  // Aplicada abaixo via luminance(); mantida para clareza.
  return [luminance(fgHex), luminance(bgHex)];
}

function contrastRatio(fgHex, bgHex) {
  const [lfg, lbg] = relativeLuminance(fgHex, bgHex);
  if (lfg === null || lbg === null) return null;
  const lighter = Math.max(lfg, lbg);
  const darker = Math.min(lfg, lbg);
  return (lighter + 0.05) / (darker + 0.05);
}

// Coleta custom properties definidas em :root (paleta clara) e em
// [data-tema="escuro"] dentro do mesmo arquivo, para resolver var(--x).
function collectVars(css) {
  const vars = { claro: {}, escuro: {} };
  const rootBlocks = [...css.matchAll(/:root\s*\{([^}]*)\}/g)];
  for (const block of rootBlocks) declVarsInto(vars.claro, block[1]);
  const darkBlocks = [...css.matchAll(/\[data-tema=["']escuro["']\]\s*:root\s*\{([^}]*)\}/g)]
    .concat([...css.matchAll(/\[data-tema=["']escuro["']\]\s*\{([^}]*)\}/g)]);
  for (const block of darkBlocks) declVarsInto(vars.escuro, block[1]);
  return vars;
}

function declVarsInto(target, body) {
  for (const m of body.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) {
    const value = m[2].trim();
    if (/^#[0-9a-fA-F]{3,8}$/.test(value)) target[m[1]] = value;
  }
}

function resolveToken(value, vars, tema) {
  const v = value.trim();
  if (/^#[0-9a-fA-F]{3,8}$/.test(v)) return v;
  const m = v.match(/var\((--[\w-]+)\)/);
  if (!m) return null;
  const paletas = tema === "escuro" ? [vars.escuro, vars.claro] : [vars.claro, vars.escuro];
  for (const paleta of paletas) if (paleta[m[1]]) return paleta[m[1]];
  return null;
}

function isSolidColor(value) {
  return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value.trim())
    || /^var\((--[\w-]+)\)$/.test(value.trim())
    || /^(rgb|rgba|hsl)\(/.test(value.trim());
}

function rgbToHex(value) {
  const m = value.match(/rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
  if (!m) return null;
  // Fundos e cores com alpha ficam fora do escopo da triagem: compositar
  // sobre um parent desconhecido produz resultado enganoso.
  const alpha = value.match(/,(\s*)([\d.]+)\)$/);
  if (alpha && Number(alpha[2]) !== 1) return null;
  return "#" + [m[1], m[2], m[3]].map(n => Number(n).toString(16).padStart(2, "0")).join("");
}

function parseDeclarations(body) {
  const decls = [];
  for (const m of body.matchAll(/(^|;)\s*([\w-]+)\s*:\s*([^;]*)(?=;|$)/g)) {
    if (m[2] && m[3]) decls.push({ prop: m[2].trim(), value: m[3].trim() });
  }
  return decls;
}

for (const path of cssPaths) {
  const css = await readFile(path, "utf8");
  const vars = collectVars(css);
  // Remove comentários preservando quebras, depois varre blocos reais.
  const limpo = css.replace(/\/\*[\s\S]*?(?:\*\/|$)/g, m => "\n".repeat(m.split("\n").length - 1) + "\n".repeat(m.length));
  const relative = path.slice(root.length + 1);

  // rules de escopo por tema: [data-tema="escuro"] seletor { ... }
  const themeScopes = [];
  const escuroGlobalRegex = /\[data-tema=["']escuro["']\]([^{]*)\{([^}]*)\}/g;
  let match;
  while ((match = escuroGlobalRegex.exec(limpo)) !== null) {
    themeScopes.push({ tema: "escuro", selector: `[data-tema=escuro] ${match[1].trim()}`, body: match[2] });
  }

  const plainBlocks = [];
  const plainRegex = /(^|})((?:[^{}]*))\{([^{}]*)\}/g;
  while ((match = plainRegex.exec(limpo)) !== null) {
    plainBlocks.push({ selector: match[2].trim(), body: match[3] });
  }

  const blocks = [
    ...plainBlocks.map(b => ({ tema: /[[]data-tema=["']escuro/.test(b.selector) ? "escuro" : "claro", ...b })),
    ...themeScopes,
  ];

  for (const block of blocks) {
    const decls = parseDeclarations(block.body);
    if (!decls.length) continue;
    const fg = decls.slice().reverse().find(d => d.prop === "color"); // última declaração vence
    const bgDecl = decls.slice().reverse().find(d =>
      d.prop === "background-color" ||
      (d.prop === "background" && !/url|gradient/.test(d.value)));
    if (!fg || !bgDecl) continue;
    const fgHex = resolveToken(fg.value, vars, block.tema) || rgbToHex(fg.value)
      || (/^#[0-9a-fA-F]{3,8}$/.test(fg.value) ? fg.value : null)
      || (/^(?:rgb|rgba|hsl)/.test(fg.value) ? rgbToHex(fg.value) : null);
    const bgHex = resolveToken(bgDecl.value, vars, block.tema) || rgbToHex(bgDecl.value);
    if (!fgHex || !bgHex) continue;
    if (fgHex === bgHex) continue;
    // Transparências e gradientes ficam fora do escopo da triagem.
    if (!isSolidColor(fgHex) || !isSolidColor(bgHex)) continue;
    const ratio = contrastRatio(fgHex, bgHex);
    if (ratio === null) continue;
    pairsChecked++;
    const fsDecl = decls.find(d => d.prop === "font-size");
    const fs = fsDecl ? parseFloat(fsDecl.value) : null;
    const fwDecl = decls.find(d => d.prop === "font-weight");
    const weight = fwDecl ? parseInt(fwDecl.value, 10) : 400;
    const isLarge = fs !== null && !Number.isNaN(fs) && (fs >= 24 || (fs >= 18.66 && weight >= 700));
    const minimum = isLarge ? 3 : 4.5;
    const violated = ratio < minimum;
    // Ignora pares deliberados de texto sobre fundo escuro em temas claros
    // quando a intentão é terminar invisível estado ambiguo — aqui nada é
    // ignorado: o relatório é rede de segurança, triagem manual decide.
    if (violated) {
      const registro = `${relative} :: tema=${block.tema} :: seletor="${block.selector.slice(0, 90)}" :: fg=${fgHex} bg=${bgHex} :: ${ratio.toFixed(2)}:1 (${isLarge ? "texto grande" : "texto normal"})`;
      if (isLarge) failLarge.push(registro); else failSmall.push(registro);
    }
  }
}

const header = [
  "Auditoria de contraste WCAG AA — " + new Date().toISOString().slice(0, 10),
  `Arquivos analisados: ${cssPaths.length} · pares declarados no mesmo bloco: ${pairsChecked}`,
  "",
];

const outFile = header
  .concat(failSmall.length ? ["## Falhas de texto normal (< 4.5:1)"] : ["## Falhas de texto normal: 0 ✔"], failSmall, [""])
  .concat(failLarge.length ? ["## Falhas de texto grande (< 3:1)"] : ["## Falhas de texto grande: 0 ✔"], failLarge, [""]);

console.log(outFile.join("\n"));
process.exit(failSmall.length + failLarge.length > 0 ? 1 : 0);
