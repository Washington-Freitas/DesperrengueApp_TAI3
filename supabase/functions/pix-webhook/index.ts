// Edge Function: pix-webhook
//
// Recebe a notificacao "Pix pago" do gateway (sandbox ou producao) e credita a carteira
// do cliente. Aceita um payload NORMALIZADO:
//     { "txid": "DSP...", "amount_cents": 7000, "status": "paid", "provider_ref": "abc" }
// Para um gateway especifico (Mercado Pago, Asaas, Efi) basta um adaptador fino na frente
// que traduza o corpo/assinatura do provedor para este formato (ver ADR-0018).
//
// Seguranca:
//  * exige o header `x-webhook-secret` (segredo PIX_WEBHOOK_SECRET, comparacao em tempo
//    constante) - sem ele, 401;
//  * o valor e o txid sao conferidos no banco (`confirm_topup`): divergencia = recusado;
//  * idempotente: o gateway pode reenviar o mesmo aviso quantas vezes quiser (nao duplica);
//  * nada sensivel e logado.
import { createClient } from "@supabase/supabase-js";

const SECRET = Deno.env.get("PIX_WEBHOOK_SECRET") ?? "";
const admin = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", {
  auth: { persistSession: false },
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const provided = req.headers.get("x-webhook-secret") ?? "";
  if (!SECRET || !safeEqual(provided, SECRET)) return json({ error: "Unauthorized" }, 401);

  const body = await req.json().catch(() => null);
  const txid = typeof body?.txid === "string" ? body.txid : "";
  const cents = Number(body?.amount_cents);
  if (!/^DSP[0-9A-F]{22}$/.test(txid) || !Number.isInteger(cents) || cents <= 0) {
    return json({ error: "Payload inválido." }, 400);
  }
  if (body?.status !== "paid") return json({ ok: true, ignored: body?.status ?? "unknown" });

  const ref = typeof body?.provider_ref === "string" ? body.provider_ref.slice(0, 80) : "webhook";
  const { data, error } = await admin.rpc("confirm_topup", { p_txid: txid, p_amount_cents: cents, p_provider_ref: ref });
  if (error) {
    console.error("pix-webhook", error.code);
    return json({ error: error.code === "P0002" ? "Cobrança não encontrada." : "Não confirmado." }, error.code === "P0002" ? 404 : 409);
  }
  return json({ ok: true, ...data });
});
