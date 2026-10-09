import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// Variáveis injetadas pelo Supabase
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Inicializa o cliente com privilégios de administrador (para ler o e-mail em auth.users)
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// A tipagem : Request resolve o aviso vermelho "Parameter 'req' implicitly has an 'any' type"
serve(async (req: Request) => {
  try {
    // 1. Recebe o gatilho da tabela 'profiles'
    const payload = await req.json();
    const record = payload.record;

    // Proteção: Só dispara se o status for exatamente o esperado
    if (!record || record.verification_status !== 'APPROVED_PENDING_EMAIL') {
      return new Response(
        JSON.stringify({ message: "Status não exige envio de e-mail." }),
        { headers: { "Content-Type": "application/json" }, status: 200 }
      );
    }

    const userId = record.id;
    const nomeProfissional = record.nome_completo || "Profissional";

    // 2. Busca o e-mail seguro na tabela auth.users usando o Service Role
    const { data: userAuth, error: authError } = await supabaseAdmin.auth.admin.getUserById(userId);
    
    if (authError || !userAuth.user) {
      throw new Error(`Erro ao buscar e-mail em auth.users: ${authError?.message}`);
    }

    const emailProfissional = userAuth.user.email;

    // 3. Monta o E-mail em HTML (Design Profissional)
    const htmlTemplate = `
      <!DOCTYPE html>
      <html lang="pt-PT">
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: 'Inter', sans-serif; background-color: #F8FAFC; color: #0F172A; }
          .container { max-width: 600px; margin: 40px auto; background-color: #FFFFFF; border-radius: 16px; padding: 32px; box-shadow: 0 4px 24px rgba(0,0,0,0.04); }
          .btn { background-color: #2563EB; color: #FFFFFF; text-decoration: none; padding: 16px 32px; border-radius: 12px; font-weight: bold; display: inline-block; margin-top: 20px;}
        </style>
      </head>
      <body>
        <div class="container">
          <h2>Tudo pronto, ${nomeProfissional}! 🎉</h2>
          <p>A nossa equipa concluiu a análise da sua documentação e a sua conta de parceiro oficial <strong>foi aprovada com sucesso.</strong></p>
          <p>Para ativar o seu acesso e começar a configurar o seu portfólio, clique no botão abaixo através do seu telemóvel:</p>
          
          <a href="desperrengue://onboarding/ativar?token=${userId}" class="btn">
            Ativar e Configurar Perfil
          </a>
          
          <p style="margin-top: 30px; font-size: 13px; color: #64748B;">© 2026 Desperrengue.</p>
        </div>
      </body>
      </html>
    `;

    // 4. Dispara a requisição para a API do Resend
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        // Utilizando o domínio 'desperrengue.tech' que está verificado
        from: "Equipa Desperrengue <onboarding@desperrengue.tech>", 
        to: [emailProfissional],
        subject: "A sua conta Desperrengue foi aprovada!",
        html: htmlTemplate,
      }),
    });

    const data = await res.json();

    return new Response(
      JSON.stringify({ success: true, resendResponse: data }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    );

  // A tipagem : any (ou Error) no catch resolve o aviso "error is of type unknown"
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message || "Erro desconhecido" }),
      { headers: { "Content-Type": "application/json" }, status: 400 }
    );
  }
});