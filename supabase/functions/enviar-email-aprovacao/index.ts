// Edge Function: enviar-email-aprovacao
//
// Disparada pelo trigger `profiles_notify_kyc_approved` (pg_net) quando o KYC
// de um profissional passa para APPROVED_PENDING_EMAIL.
//
// Segurança:
//  - exige o header `x-webhook-secret` (mesmo valor guardado no Vault do banco
//    como `kyc_webhook_secret` e nos secrets da função como WEBHOOK_SECRET);
//  - o deep link NÃO carrega mais o id do usuário: ele só abre o app; quem
//    autoriza a ativação é a sessão + o status no servidor (RPC activate_provider);
//  - todo texto dinâmico é escapado antes de entrar no HTML.
import { createClient } from "npm:@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM = Deno.env.get("EMAIL_FROM") ??
  "Equipe Desperrengue <onboarding@desperrengue.tech>";
const DEEP_LINK = Deno.env.get("ONBOARDING_DEEP_LINK") ??
  "desperrengue://onboarding/ativar";

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

// Comparação em tempo constante (evita timing attack no segredo).
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

function buildHtml(nome: string): string {
  const safeName = escapeHtml(nome);
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Sua conta Desperrengue foi aprovada!</title>
</head>
<body style="margin:0;padding:0;background:#F8FAFC;font-family:Inter,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0F172A;">
  <div style="max-width:600px;margin:40px auto;background:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.04);">
    <div style="background:#003366;padding:32px 24px;text-align:center;">
      <h1 style="color:#FFFFFF;margin:0;font-size:24px;font-weight:700;">Desperrengue</h1>
    </div>
    <div style="padding:32px 24px;">
      <h2 style="margin:0 0 16px;font-size:20px;color:#001A33;">Tudo pronto, ${safeName}! 🎉</h2>
      <p style="font-size:16px;line-height:1.6;color:#475569;">
        Nossa equipe concluiu a análise da sua documentação e a sua conta de parceiro
        <strong>foi aprovada com sucesso</strong>.
      </p>
      <p style="font-size:16px;line-height:1.6;color:#475569;">
        Abra o aplicativo no seu celular e toque no botão abaixo para ativar o acesso e
        montar o seu perfil público.
      </p>
      <div style="text-align:center;margin:32px 0;">
        <a href="${DEEP_LINK}"
           style="background:#2563EB;color:#FFFFFF;text-decoration:none;padding:16px 32px;border-radius:12px;font-size:16px;font-weight:700;display:inline-block;">
          Ativar e configurar perfil
        </a>
      </div>
      <p style="font-size:14px;line-height:1.5;color:#64748B;">
        Se o botão não abrir o aplicativo, abra o Desperrengue manualmente e entre com o
        seu e-mail e senha: o acesso é liberado automaticamente.
      </p>
    </div>
    <div style="text-align:center;padding:24px;font-size:13px;color:#94A3B8;border-top:1px solid #F1F5F9;">
      Se você não solicitou este cadastro, ignore este e-mail.<br />
      © 2026 Desperrengue. Todos os direitos reservados.
    </div>
  </div>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Autenticação do chamador (trigger do banco)
  const provided = req.headers.get("x-webhook-secret") ?? "";
  if (!WEBHOOK_SECRET || !safeEqual(provided, WEBHOOK_SECRET)) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const payload = await req.json();
    const record = payload?.record;

    if (!record || record.verification_status !== "APPROVED_PENDING_EMAIL") {
      return json({ message: "Status não exige envio de e-mail." });
    }
    if (typeof record.id !== "string") {
      return json({ error: "Payload inválido." }, 400);
    }

    // 2. E-mail vem de auth.users (nunca do payload)
    const { data, error } = await supabaseAdmin.auth.admin.getUserById(
      record.id,
    );
    if (error || !data?.user?.email) {
      throw new Error(`Usuário/e-mail não encontrado: ${error?.message ?? "sem e-mail"}`);
    }

    const nome = typeof record.full_name === "string" && record.full_name.trim()
      ? record.full_name.trim()
      : "Profissional";

    // 3. Envio via Resend (falha do provedor deve virar erro visível)
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM,
        to: [data.user.email],
        subject: "Sua conta Desperrengue foi aprovada!",
        html: buildHtml(nome),
      }),
    });

    const result = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("Resend error", res.status, result);
      return json({ success: false, error: "Falha ao enviar e-mail." }, 502);
    }
    return json({ success: true, id: result?.id });
  } catch (error) {
    console.error("enviar-email-aprovacao", error);
    const message = error instanceof Error ? error.message : "Erro desconhecido";
    return json({ error: message }, 400);
  }
});