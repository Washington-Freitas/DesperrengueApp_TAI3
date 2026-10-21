# LICENÇA — Desperrengue

**Copyright © 2026 Equipe Desperrengue (projeto acadêmico — Ciência da Computação, PUC Minas). Todos os direitos reservados.**

*All rights reserved.*

## 1. Natureza da licença

Este software, incluindo o código-fonte do aplicativo (`app/`), os *scripts* e migrações de banco de dados (`supabase/`), a documentação (`docs/` e arquivos `.md` da raiz), as especificações de interface e **a marca e o nome "Desperrengue"**, é **propriedade intelectual dos titulares indicados acima** e **não é software livre nem de código aberto**.

Ausente licença expressa, a lei de direitos autorais (Lei nº 9.610/1998 e, para programas de computador, Lei nº 9.609/1998) já concede ao titular direitos exclusivos. Este arquivo **explicita** essa condição e define as **únicas permissões concedidas**.

## 2. Permissões concedidas (limitadas e revogáveis)

É concedida, **gratuitamente**, licença **não exclusiva, intransferível e revogável** para:

1. **Avaliação acadêmica:** docentes, orientadores e banca da disciplina/instituição podem **clonar, executar e analisar** o código **exclusivamente** para fins de avaliação do trabalho.
2. **Leitura e estudo pessoal:** qualquer pessoa pode **ler** o código disponível publicamente neste repositório para fins educacionais.
3. **Colaboração:** pessoas convidadas pela equipe podem **modificar uma cópia local** e enviar *pull requests* ao repositório oficial, nos termos da seção 5.

## 3. Restrições

**Sem autorização prévia e por escrito dos titulares, é vedado:**

* **usar comercialmente** o software ou derivados (incluindo oferecer o serviço a terceiros, mesmo gratuitamente);
* **redistribuir, sublicenciar, vender, alugar** ou publicar o código, total ou parcialmente, fora do repositório oficial;
* **implantar uma instância própria** do aplicativo/backend para uso por terceiros;
* **remover ou alterar** avisos de direitos autorais;
* **usar o nome "Desperrengue"**, logotipos e identidade visual de forma que sugira afiliação ou endosso;
* **usar os dados, credenciais, domínios e contas** associados ao projeto (`desperrengue.tech`, projetos Supabase/Resend/Google) — nenhum desses recursos é licenciado por este arquivo;
* realizar engenharia reversa com o objetivo de contornar controles de segurança.

## 4. Componentes de terceiros

O projeto utiliza bibliotecas de código aberto (por exemplo, o *framework* **Flutter**, **supabase_flutter**, **image_picker**, **geolocator**, **app_links**, **google_sign_in**, **http**, entre outras listadas em `app/pubspec.yaml`) e serviços de terceiros (Supabase, Resend, Google, ViaCEP). **Cada um permanece sujeito à sua própria licença e termos de uso**, que **não são alterados** por este arquivo. Para gerar o inventário completo de licenças das dependências, execute `flutter pub deps` e consulte as licenças dos pacotes em *pub.dev*.

## 5. Contribuições

Ao submeter uma contribuição (código, documentação, *design*) ao repositório, você declara que **tem direito de fazê-lo** e **concede aos titulares do projeto uma licença perpétua, mundial, irrevogável, não exclusiva e isenta de royalties** para usar, reproduzir, modificar, sublicenciar e distribuir sua contribuição como parte do Desperrengue, sem prejuízo da sua autoria moral. Contribuições feitas com auxílio de ferramentas de IA devem respeitar a política do [CONTRIBUTING](CONTRIBUTING.md).

## 6. Isenção de garantia e limitação de responsabilidade

**O SOFTWARE É FORNECIDO "NO ESTADO EM QUE SE ENCONTRA" (*AS IS*), SEM GARANTIAS DE QUALQUER NATUREZA**, expressas ou implícitas, incluindo, sem limitação, garantias de comercialização, adequação a um propósito específico, não violação, segurança ou disponibilidade. Trata-se de um **MVP acadêmico**: o fluxo financeiro é **simulado** e não há processamento real de pagamentos. **Em nenhuma hipótese os titulares serão responsáveis** por danos diretos, indiretos, incidentais ou consequentes decorrentes do uso do software, na máxima extensão permitida pela lei aplicável.

## 7. Vigência, rescisão e foro

Esta licença vigora enquanto cumpridas as condições acima e **é automaticamente rescindida** em caso de violação. Os titulares podem **revogá-la** a qualquer momento mediante aviso público no repositório. Fica eleito o foro da comarca de domicílio dos titulares, com renúncia a qualquer outro, salvo disposição legal cogente em contrário.

## 8. Contato e pedidos de licenciamento

Para licença comercial, parcerias, uso diverso do previsto ou esclarecimentos: **suporte@desperrengue.tech**.

---

> **Observação aos mantenedores.** A escolha de licença é uma **decisão jurídica e estratégica** dos titulares (equipe e eventualmente a instituição de ensino, conforme o regulamento do trabalho acadêmico). Este texto adota o **padrão mais conservador** (todos os direitos reservados), que preserva todas as opções futuras. Caso se decida por **código aberto**, substitua-o por uma licença **SPDX** padronizada (por exemplo, **MIT** ou **Apache-2.0**, ou **AGPL-3.0** para impedir uso em serviços de rede sem contribuição de volta) e registre a decisão em um novo ADR. Recomenda-se validação por assessoria jurídica antes de qualquer comercialização.
