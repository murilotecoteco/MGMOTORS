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
| `ROTEIRO-TESTES-MANUAIS.md` | Casos de teste manuais, campos de evidência e critério de saída. | Executar antes da banca. |
| `ROTEIRO-DEMO.md` | Roteiro cronometrado da demonstração e plano B offline. | Ensaiar e usar no dia. |
| `CHATLING.md` | Plano, limites, retenção e pendências do chatbot. | Antes de prometer algo sobre o chatbot. |
| `AMBIENTE-TESTES-20261022.md` | Versões de sistema, navegadores e ferramentas. | Preencher a coluna de ambiente nos testes. |
| `evidencias/README.md` | Organização e regras das evidências. | Guardar logs, prints e vídeos. |

**Ordem de leitura recomendada:** Índice → Levantamentos → Próximos passos → relatório completo apenas nas partes necessárias.

---

## 2. Resumo em uma página

### Situação

- Aplicativo real: `https://mgmotorss.vercel.app`.
- Canonicals padronizados para `mgmotorss.vercel.app` (21 arquivos).
- Teste de RLS em produção: **17 PASS / 4 FAIL** até a migration ser aplicada.
- Migration de hardening: **versionada e aplicada** no projeto conectado; validação destrutiva permanece pendente em staging.
- Artigo afirma UCs que não existem: **09, 15, 20, 24, 25** — ajustar antes da banca.

### As quatro falhas de segurança

1. `anon` lê `avaliacoes`.
2. `anon` lê 49 fotos contra 4 anúncios ativos.
3. `anon` executa `promover_moderador` (HTTP 204).
4. `anon` executa `criar_tabela_carrinho` (HTTP 204).

### O bug que havia dentro da correção

A migration tentava remover `fc_insert`/`fg_insert`, mas as policies reais são `fc_upload`/`fg_upload`. Os `DROP` eram no-ops. **Corrigido e aplicado**; falta a validação destrutiva em staging.

### Os cinco bugs de demo já corrigidos no frontend

1. Links do header quebram nos blogs.
2. `?categoria=` e `?anunciar=1` são ignorados.
3. Aba “Pausados” não tem botão.
4. Aprovação de anúncio ignora erro.
5. Toast de moderação é invisível.

Correções implementadas no commit de 22/10/2026; falta validar no domínio oficial.

### A recomendação

Corrigir P0, consertar P1 e **reduzir as alegações do artigo**. Não implementar funcionalidades novas antes da banca.

---

## 3. Status atual

| Frente | Status | Observação |
|---|---|---|
| Auditoria técnica | Concluída | 22/10/2026 |
| Levantamentos | Concluídos | `LEVANTAMENTOS-20261022.md` |
| Plano de ação | Concluído | `PROXIMOS-PASSOS-20261022.md` |
| Correções de segurança | Parcial | Migration aplicada; falta validar as sondas destrutivas em staging |
| Correções de demo | Concluídas no frontend | P1 implementado; falta teste no domínio oficial |
| Correções do artigo | Parcial | Quadros 3 e 6 ajustados na versão disponível; Figuras 6–8 pendentes |
| Figuras reais | Pendentes | Figuras 6–8 ainda são mockups |
| Evidências para a banca | Roteiro pronto; coleta pendente | `ROTEIRO-TESTES-MANUAIS.md` e `evidencias/` |
| Documentação de apoio | Concluída | README, roteiro de demo e Chatling |

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

Criar uma pasta `evidencias/` (com `README.md` versionado; arquivos com dados pessoais ficam fora do controle de versão) com:

```
evidencias/
├── README.md
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
