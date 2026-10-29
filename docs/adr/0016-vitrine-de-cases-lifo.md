# ADR-0016 — Vitrine de cases (portfólio LIFO) e Case de Sucesso

* **Status:** Aceito
* **Data:** 2026-10-29
* **Decisores:** Desenvolvedor
* **Tags:** reputação, UX, banco de dados, mídia

## Contexto

O portfólio era um conjunto manual de fotos soltas. A prova social mais forte é um **serviço real, verificado e avaliado**. Faltavam: vitrine que se atualiza sozinha, dossiê técnico (vídeo, fotos, relatório, avaliação) e curadoria pelo profissional.

## Decisão

1. **Regra LIFO no banco** (`provider_showcase`): 4 vagas. Entram os serviços **concluídos com avaliação do cliente já revelada** (ADR-0011), do mais recente para o mais antigo; o 5º cai para o histórico geral. Entra sozinho só com **≥ 4★** — uma nota baixa continua na média e nas avaliações, mas não "sequestra" a vitrine.
2. **Fixar (📌):** o profissional fixa serviços de **5★** (`pin_case`), no máximo **3** — sobra 1 vaga LIFO viva para não congelar o sinal de recência. Fixados ocupam as primeiras posições.
3. **Case de Sucesso** (`provider_case_detail`): capa (foto "Ambiente Limpo"), **vídeo** (opcional, ≤ 30 s / 25 MB), galeria das 4 fotos de evidência, **relatório técnico** (`jobs.provider_report`, editável só até a conclusão, `set_job_report`) e avaliação do cliente (nome curto, pílulas, resposta).
4. **Mídia privada, leitura pública só do que é case:** o bucket `job-media` continua privado; uma *policy* extra (`_is_case_media`) libera a leitura apenas dos arquivos de evidência de cases visíveis, por URL assinada. O vídeo só é baixado ao toque em ▶.
5. **UI:** faixa horizontal (`ListView.builder`, 4 itens) no painel do profissional e no perfil público; "Gerenciar vitrine" abre o histórico com Fixar/Soltar.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Vitrine montada no app | Regra duplicada, burlável | Banco é a fonte única |
| Tornar o bucket público | Expõe fotos de casas de clientes | Viola a minimização (ADR-0007) |
| Permitir fixar 4 | Vitrine congela, perde o efeito LIFO | Limite 3 equilibra curadoria e frescor |

## Consequências

* (+) Reputação visível, verificável e que se renova sozinha.
* (+) Incentivo a capricho em fotos, vídeo e relatório (mais conversão).
* (−) Depende da avaliação do cliente (cega, até 48 h): o case aparece quando a avaliação é revelada.

## Referências

* Migration `20261029100000_offboarding_wallet_showcase.sql`; testes `offboarding_showcase_smoke.sql` (itens 15–38).
* `app/lib/features/shared/presentation/showcase_widgets.dart`.
