# Pendências para o Guilherme

## Situação atual

O MGMOTORS está funcional para a apresentação do Projeto Integrador. Os fluxos principais foram validados no ambiente publicado, e as divergências do painel administrativo foram conferidas no código.

## Verificações concluídas neste ciclo

- [x] Navbar verificada no deploy publicado em desktop.
- [x] Navbar verificada em viewport móvel de 390 × 844 px.
- [x] Menu móvel aberto e fechado sem perda dos links de navegação.
- [x] Smoke test aprovado nas cinco páginas públicas: início, marketplace, dicas, contato e login.
- [x] Smoke test ajustado para usar Chromium via Playwright e bloquear dependências externas; a verificação de disponibilidade não fica mais sujeita a timeout do Supabase, Chatling ou Web Vitals.
- [x] Painel administrativo conferido: há contadores básicos, busca de usuários, banimento e desbanimento.
- [x] Artigo atualizado para registrar que edição de usuários e relatórios detalhados não estão implementados.

## O que falta fazer

### 1. Validar os encontros de carros em staging

- [ ] Aplicar somente a migration incremental `supabase/migrations/20261106000000_encontros.sql` no projeto Supabase de staging. Não executar `MGMOTORS-BANCO-UNIFICADO.txt`.
- [ ] Testar com contas descartáveis: criação de encontro, aprovação, rejeição, listagem pública, entrada, cancelamento e limite de vagas.
- [ ] Conferir mapa, filtros, requisitos, data/horário e bloqueio de ações sem consentimento legal vigente.
- [ ] Registrar o resultado e atualizar o protocolo de testes do artigo, pois essa funcionalidade foi incorporada depois da rodada final de 25 de outubro de 2026.

### 2. Teste com pessoas externas

Realizar uma avaliação de usabilidade com cinco a oito participantes que não fizeram parte do desenvolvimento. Cada participante deve executar, preferencialmente, estas tarefas:

1. Acessar a página inicial e localizar um veículo por marca ou modelo.
2. Aplicar filtros no marketplace e abrir os detalhes de um anúncio.
3. Criar ou acessar uma conta de teste e favoritar um anúncio.
4. Enviar uma mensagem ao vendedor ou usar o formulário de contato.
5. Publicar, editar ou marcar um anúncio como vendido, usando dados fictícios.
6. Localizar as opções de ajuda, privacidade e contato.

Registrar para cada participante apenas dados necessários para a avaliação: tarefa concluída, dificuldade observada, tempo aproximado e comentário. Não registrar senha, documento, telefone ou outros dados pessoais reais. Ao final, aplicar o questionário SUS ou outro instrumento definido pelo professor e anexar um resumo anonimizado ao artigo.

### 3. Fechamento acadêmico

- [ ] Revisar o artigo conforme o modelo e as regras de formatação do curso.
- [ ] Conferir autores, referências, citações e numeração de quadros e figuras.
- [ ] Anexar, se o Chatling for apresentado como resultado, a configuração utilizada e a política de dados do serviço.
- [ ] Atualizar o artigo se alguma funcionalidade parcial for implementada depois desta revisão.
- [ ] Enviar a versão final ao orientador, incorporar as correções solicitadas e obter a aprovação para entrega/apresentação do TCC.

## Divergências funcionais que devem permanecer explícitas

- **Administração de usuários:** parcial. O painel permite buscar, banir e desbanir usuários; edição de dados cadastrais não está implementada.
- **Painel administrativo:** parcial. Há contadores básicos de usuários, anúncios, pendências, denúncias e banimentos; relatórios detalhados, exportação e histórico analítico não estão implementados.
- **Encontros de carros:** implementados no frontend e na migration incremental, mas a validação integrada com o Supabase de staging ainda está pendente; portanto, devem ser apresentados como recurso complementar em validação.
- Essas limitações não devem ser descritas como funcionalidades concluídas na apresentação.

## Evidências técnicas já disponíveis

- `npm test`: validação estática aprovada.
- `npm run test:a11y`: validação de contraste e pares de cores aprovada.
- `npm run test:e2e -- --workers=1`: 17 testes aprovados e 1 ignorado na última rodada registrada, incluindo rota, modal, controles responsivos e aceite legal dos encontros/login.
- `npm run test:smoke`: 5 páginas públicas aprovadas; o smoke verifica disponibilidade/HTML/CSS e os fluxos JavaScript ficam cobertos pelo E2E.
- Rodada final registrada com Chromium e Firefox.
