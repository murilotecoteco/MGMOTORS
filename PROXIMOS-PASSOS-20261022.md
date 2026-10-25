# MGMOTORS — Próximos passos e plano de correção

**Criado em:** 22/10/2026  
**Horizonte:** até a banca (nov/2026 — data exata a confirmar)  
**Base:** `LEVANTAMENTOS-20261022.md`  
**Relatório completo:** `ANALISE-COMPLETA-20261022.md`

> **Atualização de execução — 25/10/2026:** os itens UC09, UC15, UC20, UC24,
> UC25 e os filtros estendidos foram implementados em
> `20261025190000_marketplace_completion.sql`. As seções de diagnóstico abaixo
> preservam o plano original; para o estado atual, consulte o `README.md` e o
> `ROTEIRO-TESTES-MANUAIS.md`.

> Este é o documento de execução. Cada item tem prioridade, esforço estimado, critério de aceite e evidência esperada. Marcar a caixa só quando o critério de aceite for cumprido.

---

## 1. Objetivo

Chegar à banca com:

1. segurança corrigida e **comprovada**;
2. demonstração funcionando de ponta a ponta;
3. artigo coerente com o código;
4. figuras reais;
5. evidências organizadas.

**Regra central:** não adicionar funcionalidade nova antes de concluir P0 e P1. O risco de regressão é maior que o ganho de implementar UC09/UC15/UC20/UC24/UC25 em cima da hora.

---

## 2. Regras de execução

- [ ] Toda correção entra em branch separada e vira commit descritivo.
- [ ] Nada é considerado pronto sem teste no domínio oficial.
- [ ] Toda mudança de banco é testada em staging antes de produção.
- [ ] Backup do banco antes de aplicar migration.
- [ ] Nenhum teste destrutivo roda contra produção.
- [ ] Cada tarefa concluída gera uma evidência (print, log, HTTP, vídeo).
- [ ] O artigo é editado em **um** arquivo canônico, não em três.

### 2.1 Arquivo canônico do artigo

- Texto: `ArtigoMG_revisado_professor.docx`
- Template: `ArtigoMG_revisado_modelo_biopark.docx`
- Importações pontuais: `ArtigoMG_revisado_MGMOTORSBR.docx` (diagrama de casos de uso e logos)

Salvar a versão final como `ArtigoMG_final_banca.docx` e **parar de editar as três variantes**.

---

## 3. P0 — Segurança e integridade (primeiros 7 dias)

### P0.1 Corrigir os nomes das policies de storage

**Arquivo:** `supabase/migrations/20261020120000_security_hardening.sql`  
**Esforço:** 30 min

- [ ] Substituir `fc_insert` por `fc_upload`.
- [ ] Substituir `fg_insert` por `fg_upload`.
- [ ] Confirmar o formato real dos caminhos antes de recriar as policies.
- [ ] Adicionar bloco de validação que aborta se as policies antigas existirem.

**Aceite:** `grep` não encontra `fc_insert`/`fg_insert`; bloco `DO $$` valida a ausência de `fc_upload`/`fg_upload` ou sua substituição.

**Evidência:** diff do arquivo + saída do bloco de validação em staging.

---

### P0.2 Aplicar a migration em staging

**Esforço:** 1 h

- [ ] Criar ou usar projeto Supabase de staging.
- [ ] Rodar `supabase db push` ou colar a migration no SQL Editor.
- [ ] Verificar se o bloco de pré-condições não aborta.
- [ ] Registrar data, ambiente e responsável.

**Aceite:** migration aplicada sem erro; schema de staging contém as novas policies e funções.

**Evidência:** log da aplicação + print do schema.

---

### P0.3 Rodar o teste de RLS corrigido em staging

**Esforço:** 1 h

- [ ] Corrigir o script para não destruir perfil.
- [ ] Rodar `[1]–[4]` e, se houver usuário descartável, `[5]–[7]`.
- [ ] Salvar saída antes/depois.

**Aceite:** `21 PASS / 0 FAIL` em staging.

**Evidência:** arquivo `evidencias/rls-antes.txt` e `evidencias/rls-depois.txt`.

---

### P0.4 Aplicar em produção

**Esforço:** 1 h, em janela de baixo uso

- [ ] Fazer backup/snapshot.
- [ ] Aplicar a migration.
- [ ] Rodar `[1]–[4]` contra produção.
- [ ] Confirmar que o app continua funcionando.

**Aceite:** `21 PASS / 0 FAIL` em produção; login, busca e publicação funcionando.

**Evidência:** print do resultado + smoke test.

> Se a aplicação em produção não for possível antes da banca, documentar o motivo e apresentar o resultado de staging. Não deixar para a última semana.

---

### P0.5 Remover e-mails de desenvolvedores do frontend

**Arquivos:** `MG-DEV/devpanel.html:273,325`, `MG-CONFIGURACOES/configuracoes.html:245`  
**Esforço:** 30 min

- [ ] Remover `ADMIN_EMAILS`.
- [ ] Remover pré-preenchimento do e-mail de admin.
- [ ] Remover lista `DEVS`.
- [ ] Usar `is_admin()` via RPC para autorização.

**Aceite:** `grep -rn '@gmail.com' --include='*.html' .` não retorna e-mails pessoais.

**Evidência:** saída do `grep`.

---

### P0.6 Corrigir XSS de imagens

**Arquivos:** `marketplace.html`, `inicio.html`, `conta.html`, `devpanel.html`  
**Esforço:** 3 h

- [ ] Importar `escapeHtml` de `mgConfig.js` nas páginas que não importam.
- [ ] Criar helper `safeImg(url, fallback)`.
- [ ] Aplicar em todos os `src` que recebem dado do banco.
- [ ] Aplicar também em `alt`, `title` e `data-*`.
- [ ] Testar com URL maliciosa em um anúncio de teste.

**Aceite:** payload `x" onerror="alert(1)` não executa; imagem cai no fallback.

**Evidência:** print/vídeo do teste.

---

### P0.7 Padronizar domínio e canonicals

**Arquivos:** 21 HTML + configuração Vercel  
**Esforço:** 1 h

- [ ] Definir o domínio oficial (`mgmotorss.vercel.app` ou domínio próprio).
- [ ] Trocar todos os canonicals.
- [ ] Redirecionar ou desativar `mgmotors.vercel.app`.
- [ ] Conferir `/api/config` no domínio oficial.

**Aceite:** todos os canonicals apontam para o domínio oficial; domínio antigo não serve o app errado.

**Evidência:** `grep` dos canonicals + `curl`.

---

### P0.8 Corrigir Quadro 3 e Quadro 6

**Arquivo:** `.docx` canônico  
**Esforço:** 4 h

- [ ] Marcar UC09, UC15, UC20, UC24 e UC25 como não implementados.
- [ ] Marcar filtros estendidos como “Não”.
- [ ] Marcar RF06, RF09, RF10, RF12 como “Parcial”.
- [ ] Separar cenários do Quadro 6.
- [ ] Remover PASS de grupos que contenham UC ausente.
- [ ] Revisar texto corrido que afirma essas funcionalidades.

**Aceite:** nenhuma tabela afirma “Sim” para funcionalidade inexistente.

**Evidência:** versão final do `.docx` + revisão cruzada com a matriz de UCs.

---

### P0.9 Substituir Figuras 6–8 por capturas reais

**Esforço:** 3 h

- [ ] Publicar um anúncio de teste com fotos reais.
- [ ] Capturar marketplace com filtros visíveis.
- [ ] Capturar painel de moderação.
- [ ] Capturar detalhe e publicação.
- [ ] Atualizar legendas e fontes.
- [ ] Verificar resolução e legibilidade.

**Aceite:** nenhuma figura com “IMAGEM DO VEÍCULO” ou aparência de mockup.

**Evidência:** imagens originais + figura no documento.

---

### P0.10 Proteger o script de teste

**Arquivo:** `supabase/tests/rls-security-check.sh`  
**Esforço:** 1 h

- [ ] Adicionar aviso no cabeçalho: “staging only”.
- [ ] Não rodar `[5]–[7]` sem `AUTH_TOKEN` de usuário descartável.
- [ ] Implementar `trap` de limpeza.
- [ ] Usar `before` para restaurar o perfil ou remover a captura morta.
- [ ] Documentar no README do teste.

**Aceite:** executar o script sem variáveis não altera nenhum dado.

**Evidência:** teste em staging + diff do script.

---

## 4. P1 — Demonstração e experiência (dias 8 a 21)

### P1.1 Links de blog

- [ ] Trocar `../MG-DICAS/dicas.html` por `/MG-DICAS/dicas.html` em `headerGlobal.js:35`.
- [ ] Testar a partir de um blog, da home e do marketplace.

**Aceite:** “Dicas” funciona em qualquer profundidade.

---

### P1.2 Parâmetros de URL no marketplace

- [ ] Ler `?anunciar=1` e abrir o modal (ou redirecionar para login).
- [ ] Ler `?categoria=` e aplicar o filtro correspondente.
- [ ] Definir o mapeamento de categoria com semântica real (não inventar).
- [ ] Testar os links da home.

**Aceite:** “Anunciar Agora” e os cards de categoria levam ao estado correto.

---

### P1.3 Aba “Pausados”

- [ ] Adicionar botão `data-tab="pausados"` em `conta.html`.
- [ ] Garantir que o handler existente trate a aba.
- [ ] Testar pausar, listar e reativar.

**Aceite:** aba visível e funcional; ou removida por completo, se a decisão for não expor.

---

### P1.4 Aprovação com checagem de erro

- [ ] Capturar `{ error }` em `devpanel.html:418`.
- [ ] Mostrar toast de erro e não remover o card.
- [ ] Testar com RLS bloqueando.

**Aceite:** UI nunca diz “aprovado” quando o banco recusou.

---

### P1.5 Toast visível

- [ ] Linkar `devpanel.css` ou adicionar CSS de `.toast` em `global.css`.
- [ ] Estilizar `success`, `error`, `warning`.
- [ ] Testar aprovar, rejeitar e banir.

**Aceite:** feedback visível em todas as ações de moderação.

---

### P1.6 Leituras de `usuarios_publicos`

- [ ] Substituir `from("usuarios")` por `from("usuarios_publicos")` em `mensagens.html`.
- [ ] Fazer o mesmo em `conta.html:457`.
- [ ] Testar chat entre duas contas.

**Aceite:** nome e foto do interlocutor aparecem corretamente.

---

### P1.7 Debounce na busca

- [ ] Implementar debounce de 250–300 ms em `marketplace.html:813`.
- [ ] Testar digitação rápida.

**Aceite:** uma filtragem por pausa de digitação, não por tecla.

---

### P1.8 Fallback do `mgConfig.js`

- [ ] Não lançar erro no topo do módulo.
- [ ] Exportar `configError`.
- [ ] Exibir mensagem amigável nas páginas.
- [ ] Testar com `/api/config` indisponível.

**Aceite:** falha de config mostra aviso, não tela em branco.

---

### P1.9 Modais acessíveis

- [ ] Adicionar `role="dialog"` e `aria-modal="true"`.
- [ ] Implementar focus trap.
- [ ] Fechar com ESC.
- [ ] Retornar o foco ao botão de origem.
- [ ] Testar só com teclado.

**Aceite:** Tab não escapa do modal; ESC fecha; foco retorna.

---

### P1.10 Guarda de `quilometragem`

- [ ] Usar `Number(a.quilometragem || 0).toLocaleString()` em `conta.html`.
- [ ] Revisar outros pontos com o mesmo padrão.

**Aceite:** card não quebra se vier valor nulo de RPC/legado.

---

### P1.11 Fotos do chat

- [ ] Decidir: bucket privado com URL assinada **ou** remover upload de foto no chat para a banca.
- [ ] Se privado: criar bucket `mensagens`, path com `conversa_id`, policies de participante, `createSignedUrl`.
- [ ] Testar com duas contas.

**Aceite:** URL pública não acessa foto de conversa; participante acessa.

---

### P1.12 Paginação da RPC

- [ ] Adicionar `LIMIT`/`OFFSET` em `get_anuncios_marketplace`.
- [ ] Remover o parâmetro livre de `usuario_id` ou ignorá-lo.
- [ ] Ajustar o frontend.

**Aceite:** resposta limitada; `usuario_curtiu` reflete apenas o usuário autenticado.

---

## 5. P2 — Acabamento (dias 22 a 35)

- [ ] P2.1 Roteiro de testes manuais com data, navegador, resolução e evidência.
- [ ] P2.2 Revisão de acessibilidade: contraste, labels, navegação por teclado.
- [ ] P2.3 Reduzir N+1 no chat e na conta.
- [ ] P2.4 Headers de segurança no `vercel.json` (CSP, `X-Frame-Options`, `Referrer-Policy`).
- [ ] P2.5 Documentar Chatling: versão, plano, base de conhecimento, retenção.
- [ ] P2.6 Atualizar `README.md` com o estado real.
- [ ] P2.7 Ensaio geral cronometrado.
- [ ] P2.8 Plano B offline: prints e vídeo de 5–8 min.

---

## 6. Cronograma

| Semana | Período | Foco | Entrega |
|---|---|---|---|
| 1 | 22–28/10 | P0 segurança + artigo | Migration aplicada, tabelas corrigidas |
| 2 | 29/10–04/11 | P1 bugs de demo | Roteiro de demo funcionando |
| 3 | 05–11/11 | P1 restante + figuras | Artigo com capturas reais |
| 4 | 12–18/11 | P2 + ensaio | Evidências e ensaio cronometrado |
| 5 | 19–25/11 | Buffer | Correções de última hora |

**A confirmar:** data exata da banca. Se for antes de 19/11, comprimir P2 e priorizar P0/P1.

---

## 7. Roteiro de demonstração

Ensaar nesta ordem, com duas contas abertas (comprador e vendedor) e uma conta admin.

1. **Home:** navegação, busca, cards de categoria.
2. **Cadastro/login:** criar conta de teste ou entrar com conta preparada.
3. **Publicação:** anunciar veículo com foto; mostrar validação.
4. **Marketplace:** buscar, filtrar por tipo/marca/preço/estado, ordenar.
5. **Detalhe:** abrir anúncio, ver fotos, dados do vendedor.
6. **Favorito e curtida:** demonstrar persistência.
7. **Contato:** WhatsApp e mensagem interna.
8. **Chat:** conversa entre as duas contas; foto (se a correção estiver pronta).
9. **Denúncia:** denunciar um anúncio.
10. **Moderação:** admin aprova/rejeita; mostrar toast e atualização.
11. **Perfil:** editar dados, ver perfil público.
12. **Segurança:** mostrar o script de RLS com 21/21 e explicar as correções.

**Não incluir na demo:** edição de anúncio, categorias, marcar como vendido, compartilhar, formulário de contato e notificações persistentes.

---

## 8. Checklist do artigo

### 8.1 Conteúdo

- [ ] Quadro 3 corrigido.
- [ ] Quadro 6 corrigido.
- [ ] Texto corrido sem afirmar UC09/15/20/24/25.
- [ ] RF02, RF06, RF09, RF10 e RF12 marcados como parciais.
- [ ] UC21 mantido como não funcional.
- [ ] Limitações e trabalhos futuros atualizados.
- [x] Chatling documentado: plano Free, 200 créditos de IA/mês, 1 agente, 1 assento, 500.000 caracteres na base, 25 créditos de e-mail/mês, 2 ações por agente, 1 workflow por agente, personalização limitada e marca Chatling mantida.

### 8.2 Formatação

- [ ] Uma única versão do `.docx`.
- [ ] Template Biopark aplicado.
- [ ] Figuras 4–8 reais e legendadas.
- [ ] Fontes e referências conferidas.
- [ ] URL do repositório e do deploy corretas.
- [ ] Marca “MGMOTORS” consistente (sem “MGMOTORSBR”).

### 8.3 Evidências

- [ ] Print do RLS antes (17/4).
- [ ] Print do RLS depois (21/21).
- [ ] Print/vídeo do teste de XSS.
- [ ] Roteiro de demo com prints.
- [ ] Vídeo de backup.

---

## 9. Definition of done

Uma tarefa só está concluída quando:

1. o código está no Git, em commit descritivo;
2. foi testada no domínio oficial, não só localmente;
3. tem evidência anexada;
4. não quebrou nenhum passo do roteiro de demo;
5. se alterou o artigo, a tabela correspondente foi revisada;
6. se alterou o banco, staging e produção estão documentados.

---

## 10. Próximas 48 horas

Ordem sugerida para começar imediatamente:

1. **Corrigir os nomes `fc_upload`/`fg_upload`** na migration (30 min).
2. **Subir a migration e os testes para o Git** (15 min).
3. **Preparar staging** e aplicar a migration (1 h).
4. **Rodar o teste de RLS** em staging e salvar as saídas (1 h).
5. **Remover os e-mails de dev** do frontend (30 min).
6. **Corrigir o XSS** nas quatro páginas (3 h).
7. **Trocar os canonicals** para o domínio oficial (1 h).
8. **Revisar o Quadro 3** no `.docx` canônico (2 h).

Ao final de 48 h, o projeto deve ter: migration validada em staging, e-mails removidos, XSS corrigido e canonicals padronizados.

---

## 11. Decisões pendentes

| Decisão | Impacto | Responsável | Prazo |
|---|---|---|---|
| Data exata da banca | Cronograma | Coordenação | Imediato |
| Domínio oficial | SEO e demo | Equipe | Semana 1 |
| Aplicar migration em produção ou só staging | Evidência de segurança | Equipe/orientador | Semana 1 |
| Implementar UC09/15/20/24/25 ou remover do artigo | Escopo | Equipe/orientador | Semana 1 |
| Manter upload de foto no chat | Segurança | Equipe | Semana 2 — **decidido em 25/10/2026: manter bucket público por enquanto** |
| Manter Chatling na demo | LGPD e risco | Equipe | Semana 2 |
| Corrigir toggles de privacidade ou removê-los | Honestidade da UI | Equipe | Semana 2 — **decidido em 25/10/2026: removidos** |
| Versão final do `.docx` | Entrega | Equipe | Semana 3 |

---

## 12. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Migration falhar em produção | Média | Alto | Testar em staging; backup; janela de baixo uso |
| Banca rodar o script de RLS | Média | Alto | Corrigir e deixar 21/21 |
| Artigo e código divergirem | Alta | Alto | Revisão cruzada com a matriz de UCs |
| Demo falhar por internet | Média | Alto | Vídeo de backup e plano offline |
| Tempo insuficiente | Alta | Alto | Cortar P2; não iniciar features novas |
| Perfil de teste ser destruído | Média | Médio | Nunca rodar `[5]–[7]` em produção |
| Figura mockup ser questionada | Média | Médio | Substituir por capturas reais |
| Chatling indisponível | Baixa | Médio | Gravar demo do chatbot ou remover |

---

## 13. O que não fazer

1. Não rodar `[5]–[7]` do script contra produção.
2. Não aplicar migration sem backup e sem staging.
3. Não implementar UCs ausentes em cima da hora.
4. Não editar os três `.docx` em paralelo.
5. Não usar mockup como se fosse captura.
6. Não divulgar o domínio antigo.
7. Não adicionar e-mail de admin no HTML.
8. Não prometer “LGPD compliant”.
9. Não chamar teste com 4 anúncios de benchmark.
10. Não deixar a migration fora do Git.

---

## 14. Registro de progresso

Atualizar esta seção a cada sessão de trabalho.

| Data | Tarefa | Status | Evidência | Responsável |
|---|---|---|---|---|
| 22/10/2026 | Auditoria completa | Concluída | `ANALISE-COMPLETA-20261022.md` | — |
| 22/10/2026 | Levantamentos separados | Concluída | `LEVANTAMENTOS-20261022.md` | — |
| 22/10/2026 | Plano de ação | Concluída | Este arquivo | — |
| 22/10/2026 | P0.1 | Aplicada no projeto conectado; staging pendente | Migration de Storage corrigida e validada estaticamente | — |
| | P0.2 | Pendente | | |
| | P0.3 | Pendente | | |
| | P0.4 | Pendente | | |
| 22/10/2026 | P0.5 | Concluída no frontend | Autorização via `is_admin()` e sem e-mails pessoais no HTML/JS | — |
| 22/10/2026 | P0.6 | Concluída no frontend | URLs de imagens escapadas; JavaScript validado | — |
| 22/10/2026 | P0.7 | Concluída no código | 21 canonicals e links públicos padronizados para `mgmotorss.vercel.app` | — |
| 22/10/2026 | P0.8 | Concluída na versão disponível | Quadros 3 e 6 alinhados ao código; DOCX renderizado em 22 páginas sem defeitos visuais aparentes | — |
| | P0.9 | Pendente | | |
| 22/10/2026 | P0.10 | Implementada; execução em staging pendente | Seção destrutiva exige `ALLOW_DESTRUCTIVE_PROBES=1` + `CONFIRM_STAGING=1`; restauração via `trap` e captura completa do perfil | — |
| 22/10/2026 | RF14/UC21 | Migration aplicada; teste funcional pendente | `notificacoes` e `trg_notificar_nova_mensagem` confirmados no Supabase remoto | — |
| 22/10/2026 | P1.1 | Concluída no frontend | Header usa rotas absolutas e funciona em páginas profundas | — |
| 22/10/2026 | P1.2 | Parcial controlado | `?anunciar=1` abre o modal; `?categoria=` agora filtra tipos presentes no schema e informa quando a categoria editorial não possui campo correspondente | Teste estático + revisão do schema |
| 22/10/2026 | P1.3 | Concluída no frontend | Aba “Pausados” visível e ligada ao handler existente | — |
| 22/10/2026 | P1.4 | Concluída no frontend | Aprovação verifica erro antes de remover o card | — |
| 22/10/2026 | P1.5 | Concluída no frontend | Toast do painel recebeu estilo visível e estados de erro/sucesso | — |
| 22/10/2026 | P1.6 | Concluída no frontend | Leituras de terceiros usam `usuarios_publicos` | — |
| 22/10/2026 | P1.7 | Concluída no frontend | Busca usa debounce de 280 ms | — |
| 22/10/2026 | P1.8 | Concluída no frontend | Falha de `/api/config` não lança exceção no topo do módulo | — |
| 22/10/2026 | P1.10 | Concluída no frontend | Quilometragem nula recebe fallback numérico | — |
| 24/10/2026 | P1.9 | Concluída no frontend | Modais com `role="dialog"`, `aria-modal`, foco preso, ESC e retorno de foco no marketplace, conta e mensagens | — |
| 25/10/2026 | P1.11 | Decidida: manter como está | Bucket público de fotos do chat mantido por decisão do time; risco documentado no README | — |
| 25/10/2026 | Toggles de privacidade | Concluída | Removidos de Configurações os toggles/selects sem efeito (notificações, privacidade, localização, chat, tamanho da fonte); permanecem tema escuro, senha e sessões | `npm test` |
| 25/10/2026 | P1.12 | Concluída | RPC `get_anuncios_marketplace_paginado` pagina e filtra no banco; retorno validado no projeto conectado | — |
| 24/10/2026 | P2.1 | Roteiro criado; execução pendente | `ROTEIRO-TESTES-MANUAIS.md` com casos, campos e critérios | — |
| 24/10/2026 | P2.2 | Parcial | `aria-label` em filtros/campos, `role="switch"` + `aria-checked` nos toggles, botões de ícone nomeados; contraste ainda pendente | — |
| 25/10/2026 | P2.2 | Contraste revisado | Textos secundários em `#888`/`#999`/`#7b8490`/`#737b88` (3,5–4,3:1 sobre branco) trocados por `var(--texto-suave)` (≥4,8:1) em conta, mensagens, anúncio e marketplace; `:focus-visible` global já existente conferido | Cálculo WCAG das cores + `npm test` |
| 24/10/2026 | P2.3 | Concluída no frontend | Chat e conta passaram a buscar perfis/fotos em lote (N+1 removido) | — |
| 22/10/2026 | P2.4 | Concluída | CSP e headers no `vercel.json` | — |
| 24/10/2026 | P2.5 | Documento criado; retenção a confirmar | `CHATLING.md` com plano, limites e pendências | — |
| 24/10/2026 | P2.6 | Concluída | README alinhado ao código e às limitações reais | — |
| 24/10/2026 | P2.7 | Roteiro pronto; ensaio pendente | `ROTEIRO-DEMO.md` cronometrado | — |
| 24/10/2026 | P2.8 | Checklist pronto; vídeo pendente | Plano B offline documentado | — |

**Legenda:** Pendente · Em andamento · Bloqueada · Concluída
