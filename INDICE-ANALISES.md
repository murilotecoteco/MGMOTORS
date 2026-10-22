# MGMOTORS — Índice das análises e do plano de ação

**Atualizado em:** 22/10/2026  
**Projeto:** `PROJETOS/MGMOTORS`  
**Objetivo:** organizar os documentos de diagnóstico, levantamento e execução para a banca.

---

## 1. Documentos

| Documento | Para que serve | Quando usar |
|---|---|---|
| `LEVANTAMENTOS-20261022.md` | O que foi verificado: segurança, bugs, UCs, artigo, evidências e comandos. | Ler antes de mexer no projeto; base factual. |
| `PROXIMOS-PASSOS-20261022.md` | O que fazer, em que ordem, com critério de aceite e cronograma. | Usar no dia a dia; marcar checkboxes. |
| `ANALISE-COMPLETA-20261022.md` | Relatório completo, com análise estendida e patches de código/SQL. | Consultar para implementar ou defender decisões. |
| `ANALISE-BANCA.md` | Auditoria anterior (697 linhas), preservada como histórico. | Comparar evolução; não editar. |

**Ordem de leitura recomendada:** Índice → Levantamentos → Próximos passos → relatório completo apenas nas partes necessárias.

---

## 2. Resumo em uma página

### Situação

- Aplicativo real: `https://mgmotorss.vercel.app`.
- Domínio antigo `mgmotors.vercel.app` serve **outro** aplicativo.
- 21 canonicals apontam para o domínio errado.
- Teste de RLS em produção: **17 PASS / 4 FAIL**.
- Migration de hardening: **não versionada e não aplicada**.
- Artigo afirma UCs que não existem: **09, 15, 20, 24, 25**.

### As quatro falhas de segurança

1. `anon` lê `avaliacoes`.
2. `anon` lê 49 fotos contra 4 anúncios ativos.
3. `anon` executa `promover_moderador` (HTTP 204).
4. `anon` executa `criar_tabela_carrinho` (HTTP 204).

### O bug dentro da correção

A migration tenta remover `fc_insert`/`fg_insert`, mas as policies reais são `fc_upload`/`fg_upload`. Os `DROP` não fazem nada.

### Os cinco bugs que mais atrapalham a demo

1. Links do header quebram nos blogs.
2. `?categoria=` e `?anunciar=1` são ignorados.
3. Aba “Pausados” não tem botão.
4. Aprovação de anúncio ignora erro.
5. Toast de moderação é invisível.

### A recomendação

Corrigir P0, consertar P1 e **reduzir as alegações do artigo**. Não implementar funcionalidades novas antes da banca.

---

## 3. Status atual

| Frente | Status | Observação |
|---|---|---|
| Auditoria técnica | Concluída | 22/10/2026 |
| Levantamentos | Concluídos | `LEVANTAMENTOS-20261022.md` |
| Plano de ação | Concluído | `PROXIMOS-PASSOS-20261022.md` |
| Correções de segurança | Pendentes | Migration não aplicada |
| Correções de demo | Pendentes | P1 não iniciado |
| Correções do artigo | Pendentes | Quadros 3 e 6 |
| Figuras reais | Pendentes | Figuras 6–8 são mockups |
| Evidências para a banca | Pendentes | Ainda não coletadas |

---

## 4. Ordem de execução

1. **Semana 1:** P0 — segurança, e-mails, XSS, domínio, artigo.
2. **Semana 2:** P1 — bugs de demonstração.
3. **Semana 3:** P1 restante + figuras reais.
4. **Semana 4:** P2 + ensaio.
5. **Semana 5:** buffer.

Detalhes em `PROXIMOS-PASSOS-20261022.md`, seção 6.

---

## 5. Regras de manutenção

- Atualizar o registro de progresso em `PROXIMOS-PASSOS-20261022.md` a cada sessão.
- Não alterar `ANALISE-BANCA.md`; ele é histórico.
- Se um achado for refutado, mover para a seção “NÃO REPRODUZIDO” em `LEVANTAMENTOS-20261022.md` com a justificativa.
- Se uma correção for aplicada, mudar o status e anexar a evidência.
- Manter a nomenclatura de prioridade: P0, P1, P2.
- Manter as datas no formato `AAAAMMDD` nos nomes de arquivo.

---

## 6. Evidências sugeridas

Criar uma pasta `evidencias/` (fora do controle de versão, se contiver dados pessoais) com:

```
evidencias/
├── rls-antes.txt
├── rls-depois.txt
├── xss-teste.png
├── demo-roteiro.md
├── prints/
│   ├── home.png
│   ├── marketplace.png
│   ├── publicacao.png
│   ├── moderacao.png
│   └── perfil.png
└── video-backup.mp4
```

**Atenção:** não versionar prints com dados pessoais, e-mails ou tokens.

---

## 7. Perguntas abertas

- Data exata da banca.
- Domínio oficial definitivo.
- Aplicar a migration em produção ou apenas em staging.
- Implementar ou remover UC09/15/20/24/25 do artigo.
- Manter upload de foto no chat.
- Manter Chatling na demonstração.
- Corrigir ou remover os toggles de privacidade.

As decisões e prazos estão na seção 11 de `PROXIMOS-PASSOS-20261022.md`.

---

## 8. Critério de encerramento

O trabalho estará pronto para a banca quando:

- [ ] O script de RLS retornar 21/21 no ambiente apresentado.
- [ ] Nenhum e-mail pessoal estiver no HTML público.
- [ ] O XSS estiver corrigido e testado.
- [ ] O roteiro de demo rodar sem 404, modal quebrado ou tela em branco.
- [ ] O artigo não afirmar UC inexistente.
- [ ] As Figuras 6–8 forem capturas reais.
- [ ] Houver evidências salvas e um vídeo de backup.
