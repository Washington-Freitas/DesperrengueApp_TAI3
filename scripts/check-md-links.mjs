#!/usr/bin/env node
// Verificador de links relativos em arquivos Markdown.
//
//   node scripts/check-md-links.mjs            # verifica todo o repositório
//
// Falha (código 1) se algum link relativo apontar para arquivo/pasta inexistente.
// Ignora URLs externas (http, https, mailto), âncoras puras (#...) e pastas geradas
// (node_modules, build, .dart_tool, ephemeral, .git).
import { readdirSync, readFileSync, existsSync, statSync } from 'node:fs';
import { dirname, join, resolve, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SKIP = new Set(['node_modules', 'build', '.dart_tool', 'ephemeral', '.git', '.gradle', 'Pods']);

export function listMarkdown(dir = root, out = []) {
  for (const name of readdirSync(dir)) {
    if (SKIP.has(name)) continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) listMarkdown(p, out);
    else if (name.toLowerCase().endsWith('.md')) out.push(p);
  }
  return out;
}

/** Extrai alvos de links `](alvo)` (com parênteses balanceados) e `[ref]: alvo`. */
export function extractTargets(text) {
  const found = [];
  let i = 0;
  while ((i = text.indexOf('](', i)) !== -1) {
    let depth = 1;
    let j = i + 2;
    while (j < text.length && depth > 0) {
      const ch = text[j];
      if (ch === '(') depth++;
      else if (ch === ')') depth--;
      else if (ch === '\n') break;
      j++;
    }
    if (depth === 0) found.push({ start: i + 2, end: j - 1, raw: text.slice(i + 2, j - 1) });
    i = j;
  }
  for (const m of text.matchAll(/^\[[^\]]+\]:\s*(\S+)/gm)) {
    const start = m.index + m[0].length - m[1].length;
    found.push({ start, end: start + m[1].length, raw: m[1] });
  }
  return found;
}

/** Separa o caminho do alvo (sem título, sem âncora, sem <>). Null se não for caminho local. */
export function localPath(raw) {
  let t = raw.trim();
  if (t.startsWith('<')) {
    const close = t.indexOf('>');
    if (close > 0) t = t.slice(1, close);
  } else {
    t = t.split(/\s+"/)[0];
  }
  if (!t || t.startsWith('#') || /^[a-z][a-z0-9+.-]*:/i.test(t)) return null;
  const clean = t.split('#')[0].split('?')[0];
  if (!clean) return null;
  try {
    return decodeURIComponent(clean);
  } catch {
    return clean;
  }
}

function main() {
  const broken = [];
  let total = 0;
  for (const file of listMarkdown()) {
    const text = readFileSync(file, 'utf8');
    // ignora blocos de código para não acusar exemplos
    const noCode = text.replace(/```[\s\S]*?```/g, (m) => m.replace(/[^\n]/g, ' '));
    for (const t of extractTargets(noCode)) {
      const p = localPath(t.raw);
      if (p === null) continue;
      total++;
      const abs = resolve(dirname(file), p);
      if (!existsSync(abs)) {
        const line = text.slice(0, t.start).split('\n').length;
        broken.push(`${relative(root, file).split(sep).join('/')}:${line}  ->  ${t.raw}`);
      }
    }
  }
  console.log(`Links locais verificados: ${total}`);
  if (broken.length) {
    console.error(`\nLinks quebrados (${broken.length}):`);
    for (const b of broken) console.error('  ' + b);
    process.exit(1);
  }
  console.log('Nenhum link quebrado.');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
