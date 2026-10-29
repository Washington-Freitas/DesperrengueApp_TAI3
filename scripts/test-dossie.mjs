// Teste do Dossiê de Despedida (PDF) em Node, sem Deno nem rede além do npm.
//   node scripts/test-dossie.mjs
// Copia dossie.ts para uma pasta temporária com `pdf-lib` instalado (o arquivo usa
// import "pdf-lib", resolvido pelo import map no Deno e por node_modules aqui).
import { execSync } from "node:child_process";
import { copyFileSync, mkdtempSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createRequire } from "node:module";
import assert from "node:assert/strict";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const tmp = mkdtempSync(join(tmpdir(), "dossie-"));
writeFileSync(join(tmp, "package.json"), JSON.stringify({ name: "t", type: "module", private: true }));
execSync("npm install pdf-lib@1.17.1 --silent --no-audit --no-fund", { cwd: tmp, stdio: "inherit" });
copyFileSync(join(root, "supabase/functions/excluir-conta/dossie.ts"), join(tmp, "dossie.ts"));

const m = await import(pathToFileURL(join(tmp, "dossie.ts")).href);
let ok = 0;
const t = (name, fn) => { fn(); ok++; console.log("ok   ", name); };

t("formatBRL: milhar, centavos e negativo", () => {
  assert.equal(m.formatBRL(1234.5), "R$ 1.234,50");
  assert.equal(m.formatBRL(0), "R$ 0,00");
  assert.equal(m.formatBRL(1234567.891), "R$ 1.234.567,89");
  assert.equal(m.formatBRL(-5), "-R$ 5,00");
  assert.equal(m.formatBRL(null), "R$ 0,00");
});
t("formatDate: dd/mm/aaaa e entradas inválidas", () => {
  assert.equal(m.formatDate("2026-10-29T12:00:00Z"), "29/10/2026");
  assert.equal(m.formatDate(null), "-");
  assert.equal(m.formatDate("lixo"), "-");
});
t("statusPt traduz status e preserva desconhecidos", () => {
  assert.equal(m.statusPt("completed"), "Concluído");
  assert.equal(m.statusPt("xyz"), "xyz");
});

const orders = Array.from({ length: 80 }, (_, i) => ({
  id: `AB12CD${String(i).padStart(2, "0")}`, title: `Troca de tomada ${i} — açúcar, coração ★ 😀 ${"x".repeat(i % 40)}`,
  partner: "Ana S.", status: "completed", created_at: "2026-09-01T10:00:00Z", paid: 150 + i,
}));
const data = {
  generated_at: "2026-10-29T12:00:00Z", name: "Wagner Oliveira", member_since: "2026-01-02T00:00:00Z",
  is_client: true, is_provider: true,
  client: { orders, total_spent: 12345.6, total_saved: 320 },
  provider: {
    jobs: orders.slice(0, 5).map((o) => ({ ...o, net: 100 })), total_gross: 1000, total_fee: 120, total_profit: 880, total_withdrawn: 500,
    quotes: [{ job: "AB12CD00", title: "Chuveiro", price: 99.9, status: "accepted", created_at: "2026-09-01T10:00:00Z" }],
    reviews: [{ job: "AB12CD00", rating: 5, comment: "Excelente profissional, muito educado e pontual!", created_at: "2026-09-02T10:00:00Z" }],
  },
  totals: { spent: 12345.6, saved: 320, profit: 880 },
};

const { PDFDocument } = createRequire(join(tmp, "x.js"))("pdf-lib");
const pdf = await m.buildDossiePdf(data);
const pageCount = (await PDFDocument.load(pdf)).getPageCount();
t("PDF válido (cabeçalho %PDF) e com várias páginas", () => {
  assert.equal(Buffer.from(pdf.subarray(0, 5)).toString("latin1"), "%PDF-");
  assert.ok(pageCount >= 3, `esperava >= 3 páginas, veio ${pageCount}`);
});
t("emoji e caracteres fora do WinAnsi não quebram a geração", () => assert.ok(pdf.length > 5000));

const empty = await m.buildDossiePdf({ name: "Só Cliente", is_client: true, is_provider: false, client: { orders: [] }, totals: {} });
t("conta sem histórico gera PDF sem erro", () => assert.ok(empty.length > 1500));

t("toBase64 de PDF grande (sem estourar a pilha) é reversível", () => {
  const big = new Uint8Array(600_000).map((_, i) => i % 251);
  const b64 = m.toBase64(big);
  assert.deepEqual(new Uint8Array(Buffer.from(b64, "base64")), big);
});

writeFileSync(join(tmp, "amostra.pdf"), pdf);
console.log(`\n${ok} testes OK · amostra: ${join(tmp, "amostra.pdf")} (${pdf.length} bytes)`);
