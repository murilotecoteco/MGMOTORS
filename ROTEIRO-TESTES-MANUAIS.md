# Roteiro de testes manuais — MGMOTORS

**Criado em:** 24/10/2026
**Objetivo:** padronizar a execução e a evidência dos testes de demonstração.
**Ambiente oficial:** `https://mgmotorss.vercel.app`
**Referências:** `PROXIMOS-PASSOS-20261022.md`, `AMBIENTE-TESTES-20261022.md`

> Este roteiro cobre somente o que existe no código. Os casos UC09, UC15, UC20,
> UC24, UC25 e os filtros estendidos foram concluídos na migration
> `20261025190000_marketplace_completion.sql` e devem ser testados abaixo.

## 1. Como registrar

Para cada caso, preencha uma linha na tabela da seção 4 com:

- **Data** no formato `AAAA-MM-DD`;
- **Navegador e versão** (ex.: Firefox 158.0, Chrome 156.0);
- **Resolução** real da janela (ex.: 1920×1080, 1366×768, 390×844);
- **Resultado**: `PASS`, `FAIL` ou `BLOQUEADO`;
- **Evidência**: nome do arquivo em `evidencias/`.

Um caso só é `PASS` se o critério de aceite for observado sem workaround.

## 2. Preparação

1. Duas contas de teste: **comprador** e **vendedor**.
2. Uma conta **admin** para o painel de moderação.
3. Um anúncio de teste com pelo menos uma foto real, publicado pelo vendedor.
4. Abas separadas (ou janelas anônimas) para não misturar sessões.
5. Console do navegador aberto durante o teste para registrar erros.
6. Limpar cache ou usar janela anônima para testar o primeiro acesso.

## 3. Casos

### T01 — Home e navegação

- Abrir a home e navegar por Início, Marketplace, Dicas, Mensagens, Contato,
  Ajuda e Termos.
- **Aceite:** nenhum link leva a 404; o item ativo do menu é coerente.
- **Observação:** testar “Dicas” a partir de um blog (`MG-DICAS/blogs/...`).

### T02 — Cadastro, login e logout

- Criar uma conta nova, aceitar os dois consentimentos, sair e entrar de novo.
- **Aceite:** conta criada, perfil carregado, logout encerra a sessão.
- **Observação:** o aceite legal é obrigatório no cadastro.

### T03 — Recuperação de senha

- Solicitar recuperação para um e-mail de teste e concluir o fluxo.
- **Aceite:** e-mail recebido e nova senha funciona.
- **Observação:** depende do provedor de e-mail do Supabase; registrar o tempo.

### T04 — Publicação de anúncio

- Com o vendedor, abrir “Anunciar”, preencher os campos, enviar foto principal
  e fotos adicionais.
- **Aceite:** anúncio criado com status pendente; aparece no painel admin.
- **Observação:** testar validação de WhatsApp, preço e campos obrigatórios.

### T05 — Moderação

- Com o admin, aprovar o anúncio pendente.
- **Aceite:** toast visível de sucesso; o card some da fila; o anúncio aparece
  no marketplace.
- **Negativo:** simular falha de RLS e confirmar que a UI **não** diz “aprovado”.

### T06 — Marketplace: busca e filtros

- Buscar por texto, filtrar por tipo, marca, preço e estado, e ordenar.
- **Aceite:** a lista muda de acordo com cada filtro; a paginação funciona.
- **Complemento:** repetir o teste com ano mínimo/máximo, modelo, KM máxima,
  combustível, câmbio e cor; combinar pelo menos dois filtros e limpar todos.

### T07 — Detalhe do anúncio

- Abrir um anúncio, navegar pelas fotos e conferir dados do vendedor.
- **Aceite:** modal abre, fotos carregam, link do perfil funciona.
- **Acessibilidade:** abrir com teclado, fechar com `ESC`, confirmar retorno de foco.

### T08 — Favoritos e curtidas

- Curtir um anúncio, recarregar a página e conferir a persistência.
- **Aceite:** curtida permanece; contador coerente.
- **Observação:** favoritos usam `localStorage`; testar no mesmo navegador.

### T09 — Contato e chat

- Abrir conversa entre comprador e vendedor, enviar texto e conferir o tempo real.
- **Aceite:** mensagem aparece nas duas contas; nome e foto do interlocutor
  carregam; contador de não lidas funciona.
- **Observação:** fotos do chat usam bucket privado e URL assinada; confirme que
  o destinatário autorizado visualiza e uma sessão sem autorização não visualiza.

### T10 — Denúncia

- Denunciar um anúncio e uma mensagem.
- **Aceite:** denúncia registrada e visível no painel admin.

### T11 — Perfil

- Editar nome, bio, cidade, foto e capa; abrir o perfil público em outra conta.
- **Aceite:** alterações persistem; perfil público mostra apenas dados públicos.
- **Observação:** a tela de configurações não exibe mais toggles de privacidade;
  só restam preferências com efeito real (tema, senha, sessões).

### T12 — Administração de usuários

- Buscar usuário, banir e desbanir.
- **Aceite:** status muda e o usuário banido não consegue usar o fluxo normal.

### T13 — Responsividade

- Repetir T01, T06 e T07 em 390×844 (mobile), 768×1024 (tablet) e 1366×768
  (desktop).
- **Aceite:** sem corte de conteúdo, sem rolagem horizontal e com botões
  alcançáveis.

### T14 — Segurança (somente leitura)

- Executar `supabase/tests/rls-security-check.sh` **sem** variáveis de sessão.
- **Aceite:** seções `[1]`–`[4]` executam e o resumo é registrado.
- **Regra:** nunca rodar `[5]`–`[7]` contra produção.

### T15 — Editar anúncio (UC09)

- No anúncio próprio, editar preço, descrição e dados técnicos; salvar sem trocar
  a foto e repetir trocando a foto principal.
- **Aceite:** alterações persistem, somente o proprietário consegue editar e
  anúncio vendido é bloqueado.

### T16 — Categorias (UC15)

- Com admin, cadastrar marca e modelo, alterar a categoria da marca e tentar
  excluir uma marca em uso.
- **Aceite:** CRUD autorizado no painel; duplicidade e vínculos são tratados sem
  quebrar anúncios existentes; usuário comum não possui essas ações.

### T17 — Marcar como vendido (UC20)

- No anúncio próprio, confirmar “Marcar como vendido”.
- **Aceite:** status vira vendido, data de venda é registrada e o anúncio deixa
  de aparecer na listagem pública; repetir a ação não altera outro anúncio.

### T18 — Compartilhar (UC24)

- Usar o botão de compartilhar no detalhe em celular e desktop; testar Web Share
  quando disponível e cópia do link como fallback.
- **Aceite:** o link abre o detalhe correto sem depender de login.

### T19 — Formulário de contato (UC25)

- Enviar nome, e-mail, assunto e mensagem em `/MG-CONTATO/contato.html`; testar
  campos vazios e mensagem curta.
- **Aceite:** validação bloqueia dados inválidos, sucesso limpa o formulário e o
  contato aparece na caixa de entrada do painel admin.

### T20 — Regressão de permissões

- Tentar editar/vender anúncio de outra conta e acessar CRUD de categorias sem
  admin.
- **Aceite:** RLS/RPC recusam as operações e a interface não informa sucesso.

## 4. Registro

| Caso | Data | Navegador | Resolução | Resultado | Evidência | Observações |
|---|---|---|---|---|---|---|
| T01 | | | | | | |
| T02 | | | | | | |
| T03 | | | | | | |
| T04 | | | | | | |
| T05 | | | | | | |
| T06 | | | | | | |
| T07 | | | | | | |
| T08 | | | | | | |
| T09 | | | | | | |
| T10 | | | | | | |
| T11 | | | | | | |
| T12 | | | | | | |
| T13 | | | | | | |
| T14 | | | | | | |
| T15 | | | | | | |
| T16 | | | | | | |
| T17 | | | | | | |
| T18 | | | | | | |
| T19 | | | | | | |
| T20 | | | | | | |

## 5. Critério de saída

- Todos os casos do roteiro de demonstração em `PASS`, ou com desvio documentado.
- Nenhum erro no console nos fluxos principais.
- Evidências salvas em `evidencias/` com o nome do caso.
- Limitações conhecidas registradas no `README.md` e no artigo.
