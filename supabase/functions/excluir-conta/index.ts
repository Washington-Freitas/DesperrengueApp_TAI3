// Edge Function: excluir-conta  (Offboarding LGPD + Dossiê de Despedida)
//
// Fluxo (a ORDEM é a garantia de segurança do usuário):
//   1. autentica o chamador pelo JWT dele (nunca confia em id vindo do corpo);
//   2. exige confirmação explícita ("EXCLUIR") — evita chamada acidental;
//   3. trava financeira NO SERVIDOR (saldo, custódia, serviço em andamento);
//   4. monta o dossiê (RPC) e gera o PDF em memória;
//   5. envia o e-mail com o PDF (Resend). Se NÃO for 2xx: aborta, nada é apagado;
//   6. só então: purga LGPD (RPC), remove arquivos do Storage e apaga a conta
//      de autenticação (revoga todas as sessões).
// Segredos: RESEND_API_KEY (Supabase secrets). Nada sensível vai para o log.
import { createClient } from "@supabase/supabase-js";
import { buildDossiePdf, toBase64 } from "./dossie.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM = Deno.env.get("EMAIL_FROM") ?? "Equipe Desperrengue <onboarding@desperrengue.tech>";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const esc = (v: string) =>
  v.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

function emailHtml(nome: string): string {
  return `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8" /></head>
<body style="margin:0;background:#F8FAFC;font-family:Inter,-apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#0F172A;">
  <div style="max-width:600px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden;">
    <div style="background:#1E3B70;padding:28px 24px;text-align:center;">
      <h1 style="color:#fff;margin:0;font-size:22px;">Desperrengue</h1>
    </div>
    <div style="padding:28px 24px;">
      <h2 style="margin:0 0 12px;font-size:20px;color:#1E3B70;">Até logo, ${esc(nome)}.</h2>
      <p style="font-size:16px;line-height:1.6;color:#475569;">
        Sua conta foi <strong>excluída</strong> a seu pedido. Em anexo está o seu
        <strong>Dossiê de Despedida</strong> (PDF) com todo o seu histórico: pedidos, orçamentos,
        avaliações, total gasto, total economizado e total de lucro.
      </p>
      <p style="font-size:14px;line-height:1.6;color:#64748B;">
        Removemos seus dados pessoais. Mantivemos apenas os registros financeiros exigidos por lei,
        sem nome, endereço ou vínculo com você. Guarde este e-mail: não é possível gerar o dossiê depois.
      </p>
      <p style="font-size:14px;color:#64748B;">Se não foi você, responda a este e-mail imediatamente.</p>
    </div>
    <div style="text-align:center;padding:18px;font-size:12px;color:#94A3B8;border-top:1px solid #F1F5F9;">
      © 2026 Desperrengue. Todos os direitos reservados.
    </div>
  </div>
</body></html>`;
}

// Remove todos os arquivos da pasta <uid>/ de um bucket (melhor esforço, em lotes).
async function wipeFolder(bucket: string, uid: string): Promise<number> {
  let removed = 0;
  for (let i = 0; i < 20; i++) {
    const { data, error } = await admin.storage.from(bucket).list(uid, { limit: 100 });
    if (error || !data || data.length === 0) break;
    const { error: delErr } = await admin.storage.from(bucket).remove(data.map((f) => `${uid}/${f.name}`));
    if (delErr) break;
    removed += data.length;
  }
  return removed;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Quem está chamando? (JWT do próprio usuário)
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Sessão expirada." }, 401);
  const { data: auth, error: authErr } = await admin.auth.getUser(token);
  const user = auth?.user;
  if (authErr || !user) return json({ error: "Sessão expirada." }, 401);

  // 2. Confirmação explícita
  const body = await req.json().catch(() => ({}));
  if (body?.confirm !== "EXCLUIR") return json({ error: "Confirmação ausente." }, 400);

  const email = user.email;
  if (!email) return json({ error: "Conta sem e-mail para enviar o dossiê." }, 422);

  try {
    // 3. Trava financeira (a tela já checou; aqui é a autoridade final)
    const { data: st, error: stErr } = await admin.rpc("_deletion_blockers", { p_user: user.id });
    if (stErr) throw stErr;
    if (!st?.can_delete) return json({ error: "blocked", status: st }, 409);

    // 4. Dossiê + PDF em memória
    const { data: dossier, error: dErr } = await admin.rpc("account_dossier", { p_user: user.id });
    if (dErr) throw dErr;
    const pdf = await buildDossiePdf(dossier);
    const nome = String(dossier?.name ?? "").trim().split(" ")[0] || "usuário";

    // 5. E-mail com o PDF — falha aqui NÃO apaga nada
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({
        from: FROM,
        to: [email],
        subject: "Seu Dossiê de Despedida — Desperrengue",
        html: emailHtml(nome),
        attachments: [{ filename: "dossie-de-despedida-desperrengue.pdf", content: toBase64(pdf) }],
      }),
    });
    if (!res.ok) {
      console.error("excluir-conta: Resend", res.status);
      return json({ error: "Não foi possível enviar o dossiê. Nada foi excluído; tente novamente." }, 502);
    }

    // 6. Hard delete: banco -> storage -> autenticação
    const { data: purged, error: pErr } = await admin.rpc("purge_account", { p_user: user.id });
    if (pErr) throw pErr;
    for (const bucket of ["public-media", "job-media", "kyc-documents"]) {
      await wipeFolder(bucket, user.id).catch(() => 0);
    }
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) throw delErr;

    return json({ deleted: true, ...purged });
  } catch (e) {
    console.error("excluir-conta", e instanceof Error ? e.message : "erro");
    return json({ error: "Não foi possível concluir a exclusão. Tente novamente." }, 500);
  }
});
