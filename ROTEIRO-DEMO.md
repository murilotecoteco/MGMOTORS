# Roteiro de demonstração e plano B — MGMOTORS

**Criado em:** 24/10/2026
**Uso:** ensaio cronometrado (P2.7) e plano offline (P2.8)
**Ambiente:** `https://mgmotorss.vercel.app`
**Referências:** `PROXIMOS-PASSOS-20261022.md` (seção 7), `ROTEIRO-TESTES-MANUAIS.md`

## 1. Antes de começar

- [ ] Abrir duas contas (comprador e vendedor) em janelas separadas.
- [ ] Abrir a conta admin em uma terceira janela.
- [ ] Deixar um anúncio de teste pendente para a moderação ao vivo.
- [ ] Deixar uma conversa já iniciada entre comprador e vendedor.
- [ ] Conferir internet, bateria e carregadores.
- [ ] Fechar abas, extensões e notificações que possam aparecer na tela.
- [ ] Abrir o vídeo de backup em outra janela, pronto para reproduzir.

## 2. Roteiro cronometrado (alvo: 10–12 minutos)

| Tempo | Passo | O que mostrar | Fala curta |
|---:|---|---|---|
| 0:00 | Abertura | Home e identidade visual | “Este é o marketplace MGMOTORS.” |
| 0:40 | Navegação | Menu, busca e cards de categoria | “A navegação é comum a todas as páginas.” |
| 1:30 | Cadastro/login | Conta de teste já criada | “O aceite legal é obrigatório no cadastro.” |
| 2:30 | Publicação | Modal de anúncio + upload de foto | “O anúncio entra como pendente.” |
| 4:00 | Marketplace | Busca, filtros avançados e ordenação | “Os filtros são aplicados no banco, com paginação.” |
| 5:30 | Detalhe | Modal com fotos e dados do vendedor | “O vendedor é exibido pelo perfil público.” |
| 6:30 | Favorito/curtida | Curtir e recarregar | “A curtida persiste no banco.” |
| 7:15 | Contato | WhatsApp e mensagem interna | “Há dois canais de contato.” |
| 8:00 | Chat | Conversa entre as duas contas | “As mensagens chegam em tempo real.” |
| 9:00 | Denúncia | Denunciar um anúncio | “A denúncia vai para a moderação.” |
| 9:45 | Moderação | Admin aprova/rejeita e mostra o toast | “A aprovação atualiza o marketplace.” |
| 10:30 | Gestão | Editar, vender e compartilhar anúncio | “O proprietário gerencia o ciclo do anúncio.” |
| 11:15 | Segurança | Mostrar o script de RLS e o resumo | “As políticas foram testadas com este roteiro.” |
| 12:00 | Encerramento | Limitações e trabalhos futuros | “Estas são as limitações conhecidas.” |

> Ajuste os tempos após o primeiro ensaio. O importante é não passar de 15
> minutos e deixar 3–5 minutos para perguntas.

## 3. O que não incluir

- Categorias e caixa de contatos exigem a conta admin.
- Notificações persistentes (UC21) — demonstrar somente com o fluxo entre duas contas já validado.
- Envio de foto no chat — demonstrar somente com as duas contas autorizadas; o bucket é privado.
- Toggles de privacidade como controle efetivo — o banco ainda não os aplica.

## 4. Plano B offline

### 4.1 Vídeo de backup

- Duração: 5–8 minutos.
- Conteúdo: os mesmos passos da seção 2, sem depender de internet.
- Formato: MP4, 1080p, áudio narrado.
- Local: `evidencias/ensaio-backup.mp4` (não versionar se for grande; manter
  cópia local e no drive da equipe).

### 4.2 Prints de emergência

Salvar em `evidencias/` pelo menos:

1. Home.
2. Marketplace com filtros.
3. Detalhe do anúncio.
4. Publicação.
5. Chat.
6. Painel de moderação.
7. Resumo do teste de RLS.

### 4.3 Se o Supabase pausar

O plano Free do Supabase pode pausar o banco por inatividade. Se a primeira
requisição falhar:

1. Abrir o painel do Supabase e reativar o projeto.
2. Aguardar o status “Active”.
3. Recarregar a página uma vez.
4. Se não voltar em 2 minutos, usar o vídeo de backup.

## 5. Checklist do ensaio

- [ ] Ensaio completo cronometrado.
- [ ] Nenhum 404 durante o roteiro.
- [ ] Nenhum toast invisível.
- [ ] Modal abre e fecha com teclado.
- [ ] Chat entre duas contas funcionando.
- [ ] Moderação com toast visível.
- [ ] Vídeo de backup gravado e testado.
- [ ] Prints de emergência salvos.
- [ ] Roteiro impresso ou em segunda tela.
