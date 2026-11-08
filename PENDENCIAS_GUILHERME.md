# Pendências para o Guilherme

## Situação atual

O MGMOTORS está funcional para a apresentação do Projeto Integrador. Os fluxos principais foram validados no ambiente publicado, e as divergências do painel administrativo foram conferidas no código.

## Verificações concluídas neste ciclo

- [x] Navbar verificada no deploy publicado em desktop.
- [x] Navbar verificada em viewport móvel de 390 × 844 px.
- [x] Menu móvel aberto e fechado sem perda dos links de navegação.
- [x] Smoke test aprovado nas cinco páginas públicas: início, marketplace, dicas, contato e login.
- [x] A falha anterior do smoke test foi registrada como problema de permissão do ambiente local para escutar `127.0.0.1:4173` (`EPERM`), não como falha das páginas. A execução fora do sandbox foi aprovada.
- [x] Painel administrativo conferido: há contadores básicos, busca de usuários, banimento e desbanimento.
- [x] Artigo atualizado para registrar que edição de usuários e relatórios detalhados não estão implementados.

## O que falta fazer

### 1. Teste com pessoas externas

Realizar uma avaliação de usabilidade com cinco a oito participantes que não fizeram parte do desenvolvimento. Cada participante deve executar, preferencialmente, estas tarefas:

1. Acessar a página inicial e localizar um veículo por marca ou modelo.
2. Aplicar filtros no marketplace e abrir os detalhes de um anúncio.
3. Criar ou acessar uma conta de teste e favoritar um anúncio.
4. Enviar uma mensagem ao vendedor ou usar o formulário de contato.
5. Publicar, editar ou marcar um anúncio como vendido, usando dados fictícios.
6. Localizar as opções de ajuda, privacidade e contato.

Registrar para cada participante apenas dados necessários para a avaliação: tarefa concluída, dificuldade observada, tempo aproximado e comentário. Não registrar senha, documento, telefone ou outros dados pessoais reais. Ao final, aplicar o questionário SUS ou outro instrumento definido pelo professor e anexar um resumo anonimizado ao artigo.

### 2. Fechamento acadêmico

- [ ] Revisar o artigo conforme o modelo e as regras de formatação do curso.
- [ ] Conferir autores, referências, citações e numeração de quadros e figuras.
- [ ] Anexar, se o Chatling for apresentado como resultado, a configuração utilizada e a política de dados do serviço.
- [ ] Atualizar o artigo se alguma funcionalidade parcial for implementada depois desta revisão.

## Divergências funcionais que devem permanecer explícitas

- **Administração de usuários:** parcial. O painel permite buscar, banir e desbanir usuários; edição de dados cadastrais não está implementada.
- **Painel administrativo:** parcial. Há contadores básicos de usuários, anúncios, pendências, denúncias e banimentos; relatórios detalhados, exportação e histórico analítico não estão implementados.
- Essas limitações não devem ser descritas como funcionalidades concluídas na apresentação.

## Evidências técnicas já disponíveis

- `npm test`: validação estática aprovada.
- `npm run test:a11y`: validação de contraste e pares de cores aprovada.
- `npm run test:e2e -- --workers=1`: 13 testes aprovados e 1 ignorado na última rodada registrada.
- `npm run test:smoke`: 5 páginas públicas aprovadas na execução deste ciclo.
- Rodada final registrada com Chromium e Firefox.
