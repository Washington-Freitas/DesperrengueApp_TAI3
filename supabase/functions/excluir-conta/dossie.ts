// Dossiê de Despedida: gera o PDF em memória (sem disco, sem navegador).
//
// Decisão técnica: `pdf-lib` (JS puro) em vez de Puppeteer. Edge Functions não
// trazem Chromium (cold start e pacote gigantes); pdf-lib sobe em milissegundos,
// é determinístico e testável em Node. O visual limpo vem de um layout próprio
// (cabeçalho, cartões de totais, tabelas paginadas).
//
// Segurança/LGPD: o PDF contém SÓ dados do próprio titular; a contraparte
// aparece por nome curto ("Ana S.") — minimização de dado de terceiros.
import { PDFDocument, PDFFont, PDFPage, rgb, StandardFonts } from "pdf-lib";

export type Json = Record<string, any>;

const NAVY = rgb(0.12, 0.23, 0.44); // #1E3B70 (mesma cor da splash)
const INK = rgb(0.07, 0.09, 0.15);
const MUTED = rgb(0.42, 0.45, 0.5);
const LINE = rgb(0.88, 0.9, 0.92);
const SOFT = rgb(0.94, 0.96, 0.99);

const PAGE_W = 595.28; // A4
const PAGE_H = 841.89;
const MARGIN = 44;

/** R$ 1.234,56 (sem depender de Intl no runtime). */
export function formatBRL(v: unknown): string {
  const n = Number(v ?? 0);
  const neg = n < 0;
  const [int, dec] = Math.abs(n).toFixed(2).split(".");
  return `${neg ? "-" : ""}R$ ${int.replace(/\B(?=(\d{3})+(?!\d))/g, ".")},${dec}`;
}

export function formatDate(v: unknown): string {
  if (!v) return "-";
  const d = new Date(String(v));
  if (Number.isNaN(d.getTime())) return "-";
  const p = (x: number) => String(x).padStart(2, "0");
  return `${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}`;
}

const STATUS_PT: Record<string, string> = {
  open: "Aberto", awaiting_payment: "Aguardando pagamento", in_progress: "Em andamento",
  awaiting_approval: "Aguardando aprovação", completed: "Concluído", canceled: "Cancelado",
  disputed: "Em mediação", pending: "Pendente", accepted: "Aceito", rejected: "Recusado",
  withdrawn: "Retirado", escrow: "Em custódia", released: "Liberado", refunded: "Reembolsado",
};
export const statusPt = (s: unknown) => STATUS_PT[String(s ?? "")] ?? String(s ?? "-");

/** Mantém só caracteres que a fonte padrão (WinAnsi) consegue desenhar. */
export function safeText(font: PDFFont, text: unknown): string {
  const set = new Set(font.getCharacterSet());
  let out = "";
  for (const ch of String(text ?? "").replace(/[\r\n\t]+/g, " ")) {
    out += set.has(ch.codePointAt(0)!) ? ch : "?";
  }
  return out;
}

function fit(font: PDFFont, text: string, size: number, maxW: number): string {
  if (font.widthOfTextAtSize(text, size) <= maxW) return text;
  let t = text;
  while (t.length > 1 && font.widthOfTextAtSize(t + "...", size) > maxW) t = t.slice(0, -1);
  return t + "...";
}

class Writer {
  page!: PDFPage;
  y = 0;
  pageNo = 0;
  doc: PDFDocument;
  font: PDFFont;
  bold: PDFFont;
  title: string;
  constructor(doc: PDFDocument, font: PDFFont, bold: PDFFont, title: string) {
    this.doc = doc;
    this.font = font;
    this.bold = bold;
    this.title = title;
    this.newPage();
  }

  newPage() {
    this.page = this.doc.addPage([PAGE_W, PAGE_H]);
    this.pageNo++;
    this.y = PAGE_H - MARGIN;
    if (this.pageNo > 1) {
      this.page.drawText(safeText(this.font, this.title), { x: MARGIN, y: PAGE_H - 28, size: 8, font: this.font, color: MUTED });
      this.y = PAGE_H - 52;
    }
  }

  ensure(h: number) {
    if (this.y - h < MARGIN + 18) this.newPage();
  }

  text(t: string, o: { size?: number; bold?: boolean; color?: any; x?: number; gap?: number } = {}) {
    const size = o.size ?? 10;
    const f = o.bold ? this.bold : this.font;
    this.ensure(size + (o.gap ?? 4));
    this.y -= size;
    this.page.drawText(safeText(f, t), { x: o.x ?? MARGIN, y: this.y, size, font: f, color: o.color ?? INK });
    this.y -= o.gap ?? 4;
  }

  paragraph(t: string, size = 9.5, color = MUTED) {
    const width = PAGE_W - MARGIN * 2;
    const words = safeText(this.font, t).split(" ");
    let line = "";
    for (const w of words) {
      const next = line ? `${line} ${w}` : w;
      if (this.font.widthOfTextAtSize(next, size) > width && line) {
        this.text(line, { size, color, gap: 2 });
        line = w;
      } else line = next;
    }
    if (line) this.text(line, { size, color, gap: 6 });
  }

  section(title: string) {
    this.ensure(40);
    this.y -= 12;
    this.text(title, { size: 13, bold: true, color: NAVY, gap: 6 });
    this.page.drawRectangle({ x: MARGIN, y: this.y, width: PAGE_W - MARGIN * 2, height: 1, color: LINE });
    this.y -= 8;
  }

  /** Tabela com cabeçalho repetido a cada página. */
  table(cols: { h: string; w: number; right?: boolean }[], rows: string[][]) {
    const total = cols.reduce((a, c) => a + c.w, 0);
    const scale = (PAGE_W - MARGIN * 2) / total;
    const head = () => {
      this.ensure(22);
      this.page.drawRectangle({ x: MARGIN, y: this.y - 16, width: PAGE_W - MARGIN * 2, height: 18, color: SOFT });
      let x = MARGIN + 4;
      for (const c of cols) {
        const cw = c.w * scale;
        const t = safeText(this.bold, c.h);
        const tx = c.right ? x + cw - 8 - this.bold.widthOfTextAtSize(t, 8) : x;
        this.page.drawText(t, { x: tx, y: this.y - 11, size: 8, font: this.bold, color: NAVY });
        x += cw;
      }
      this.y -= 22;
    };
    head();
    if (rows.length === 0) {
      this.text("Nenhum registro.", { size: 9, color: MUTED });
      return;
    }
    for (const r of rows) {
      if (this.y - 16 < MARGIN + 18) {
        this.newPage();
        head();
      }
      let x = MARGIN + 4;
      cols.forEach((c, i) => {
        const cw = c.w * scale;
        const t = fit(this.font, safeText(this.font, r[i] ?? ""), 8.5, cw - 10);
        const tx = c.right ? x + cw - 8 - this.font.widthOfTextAtSize(t, 8.5) : x;
        this.page.drawText(t, { x: tx, y: this.y - 9, size: 8.5, font: this.font, color: INK });
        x += cw;
      });
      this.y -= 15;
      this.page.drawRectangle({ x: MARGIN, y: this.y + 3, width: PAGE_W - MARGIN * 2, height: 0.5, color: LINE });
    }
  }

  kpi(x: number, w: number, label: string, value: string) {
    this.page.drawRectangle({ x, y: this.y - 54, width: w, height: 54, color: SOFT, borderColor: LINE, borderWidth: 0.7 });
    this.page.drawText(safeText(this.font, label), { x: x + 10, y: this.y - 18, size: 8.5, font: this.font, color: MUTED });
    this.page.drawText(safeText(this.bold, value), { x: x + 10, y: this.y - 40, size: 15, font: this.bold, color: NAVY });
  }
}

export async function buildDossiePdf(d: Json): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.setTitle("Dossiê de Despedida — Desperrengue");
  doc.setAuthor("Desperrengue");
  doc.setCreator("Desperrengue");
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const w = new Writer(doc, font, bold, "Desperrengue · Dossiê de Despedida");

  // Cabeçalho
  w.page.drawRectangle({ x: 0, y: PAGE_H - 118, width: PAGE_W, height: 118, color: NAVY });
  w.page.drawText("Desperrengue", { x: MARGIN, y: PAGE_H - 52, size: 12, font: bold, color: rgb(0.78, 0.86, 1) });
  w.page.drawText("Dossiê de Despedida", { x: MARGIN, y: PAGE_H - 80, size: 26, font: bold, color: rgb(1, 1, 1) });
  w.page.drawText(safeText(font, `${d.name ?? "Usuário"} · gerado em ${formatDate(d.generated_at)}`), {
    x: MARGIN, y: PAGE_H - 100, size: 10, font, color: rgb(0.85, 0.9, 1),
  });
  w.y = PAGE_H - 140;

  w.paragraph(
    "Este documento reúne o histórico completo da sua conta. Ele é enviado antes da exclusão definitiva dos seus " +
      "dados pessoais, conforme a LGPD (art. 18). Guarde-o: depois da exclusão não será possível gerar outro.",
  );

  // Totais
  const cw = (PAGE_W - MARGIN * 2 - 20) / 3;
  w.ensure(80);
  w.y -= 8;
  w.kpi(MARGIN, cw, "Total gasto na plataforma", formatBRL(d.totals?.spent));
  w.kpi(MARGIN + cw + 10, cw, "Total economizado", formatBRL(d.totals?.saved));
  w.kpi(MARGIN + (cw + 10) * 2, cw, "Total de lucro (profissional)", formatBRL(d.totals?.profit));
  w.y -= 66;
  w.paragraph(
    "Economia = média dos demais orçamentos recebidos menos o valor contratado, somada nos pedidos com 2 ou mais orçamentos. " +
      "Lucro = valor líquido recebido (após a comissão da plataforma).",
    8, MUTED,
  );

  w.section("Seus dados");
  w.text(`Nome: ${d.name ?? "-"}`, { size: 10 });
  w.text(`Cliente: ${d.is_client ? "sim" : "não"}   ·   Profissional: ${d.is_provider ? "sim" : "não"}   ·   Membro desde ${formatDate(d.member_since)}`, { size: 10 });

  if (d.is_client) {
    const orders: Json[] = d.client?.orders ?? [];
    w.section(`Pedidos como cliente (${orders.length})`);
    w.table(
      [{ h: "ID", w: 56 }, { h: "Serviço", w: 150 }, { h: "Profissional", w: 84 }, { h: "Status", w: 92 }, { h: "Data", w: 62 }, { h: "Valor", w: 72, right: true }],
      orders.map((o) => [String(o.id), String(o.title ?? ""), String(o.partner ?? "-"), statusPt(o.status), formatDate(o.created_at), o.paid != null ? formatBRL(o.paid) : "-"]),
    );
  }

  if (d.is_provider) {
    const jobs: Json[] = d.provider?.jobs ?? [];
    w.section(`Serviços como profissional (${jobs.length})`);
    w.table(
      [{ h: "ID", w: 56 }, { h: "Serviço", w: 150 }, { h: "Cliente", w: 84 }, { h: "Status", w: 92 }, { h: "Data", w: 62 }, { h: "Líquido", w: 72, right: true }],
      jobs.map((o) => [String(o.id), String(o.title ?? ""), String(o.partner ?? "-"), statusPt(o.status), formatDate(o.created_at), o.net != null ? formatBRL(o.net) : "-"]),
    );
    w.y -= 6;
    w.text(`Bruto: ${formatBRL(d.provider?.total_gross)}   ·   Comissão: ${formatBRL(d.provider?.total_fee)}   ·   Lucro líquido: ${formatBRL(d.provider?.total_profit)}   ·   Sacado via Pix: ${formatBRL(d.provider?.total_withdrawn)}`, { size: 9.5, bold: true });

    const quotes: Json[] = d.provider?.quotes ?? [];
    w.section(`Orçamentos enviados (${quotes.length})`);
    w.table(
      [{ h: "Pedido", w: 56 }, { h: "Serviço", w: 190 }, { h: "Status", w: 100 }, { h: "Data", w: 70 }, { h: "Valor", w: 100, right: true }],
      quotes.map((q) => [String(q.job), String(q.title ?? ""), statusPt(q.status), formatDate(q.created_at), formatBRL(q.price)]),
    );

    const revs: Json[] = d.provider?.reviews ?? [];
    w.section(`Avaliações recebidas (${revs.length})`);
    w.table(
      [{ h: "Pedido", w: 56 }, { h: "Nota", w: 40 }, { h: "Comentário", w: 320 }, { h: "Data", w: 70 }],
      revs.map((r) => [String(r.job), `${r.rating}/5`, String(r.comment ?? "-"), formatDate(r.created_at)]),
    );
  }

  w.section("O que acontece agora");
  w.paragraph(
    "Excluímos seu perfil, documentos, fotos, mensagens, endereços e demais dados pessoais. Por obrigação legal e para " +
      "proteger a outra parte de cada serviço, mantemos apenas os registros financeiros (valores, datas e identificadores " +
      "de pedido), sem nome, endereço ou qualquer vínculo com você. Se tiver dúvidas, responda a este e-mail.",
  );

  // Rodapé com paginação
  const pages = doc.getPages();
  pages.forEach((p, i) => {
    p.drawText(`Página ${i + 1} de ${pages.length}`, { x: PAGE_W - MARGIN - 60, y: 24, size: 8, font, color: MUTED });
    p.drawText("Documento gerado automaticamente pelo Desperrengue", { x: MARGIN, y: 24, size: 8, font, color: MUTED });
  });

  return await doc.save();
}

/** Base64 sem estourar a pilha com PDFs grandes. */
export function toBase64(bytes: Uint8Array): string {
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}
