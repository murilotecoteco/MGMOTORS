# Evidências — MGMOTORS

Esta pasta guarda provas de teste e apoio à banca. Cada registro informa o que
foi realmente observado, o ambiente e a limitação: uma captura não substitui a
execução ao vivo nem uma avaliação com participantes externos.

## Regras

1. Nome do arquivo: `tema-ambiente-data.extensao`.
2. Log deve preservar o resumo `PASS/FAIL` e o comando/ambiente usado.
3. Capturas sem URL ou data visível precisam de relatório complementar que
   registre esses metadados.
4. Não editar logs para ocultar uma falha; registrar também a correção.
5. Nunca incluir token, senha, e-mail pessoal ou chave de serviço.
6. Não rodar as seções destrutivas `[5]–[7]` de
   `supabase/tests/rls-security-check.sh` em produção.

## Evidências organizadas em 2026-11-13

| Evidência | Status | Arquivo | Limitação relevante |
|---|---|---|---|
| RLS antes/depois | Consolidada | `rls-antes-depois-20261113.md` | Comparação documental: não é uma nova repetição destrutiva em produção. |
| Hardening de produção | PASS | `hardening-producao-20261025.md` | 27 PASS / 0 FAIL em verificação estrutural. |
| Validação de SVG no formulário | PASS | `xss-imagem-20261113.md` | Verifica o bloqueio no cliente antes do envio; não envia arquivo ao armazenamento. |
| Navbar publicada | PASS | `navbar-publicado-20261113.md` e `.json` | Teste técnico de quatro viewports, não estudo de usabilidade. |
| Capturas públicas | Prontas | `navbar-publicado-20261113-*.png` | Home, marketplace, login e navbar responsiva, sem dados pessoais. |
| Vídeo de apoio | Pronto | `videos/video-backup-publico-20261113.mp4` | Montagem de 12 s de telas públicas; não é gravação contínua de todo o roteiro. |
| Chatling | Registrada | `chatling-configuracao-20261113.md` e `../CHATLING.md` | Avaliação exploratória, sem amostra externa. |

## Evidências automatizadas de 2026-10-25

| Evidência | Arquivo | Resultado |
|---|---|---|
| Verificador de hardening em produção | `hardening-producao-20261025.md` | 27 PASS / 0 FAIL |
| Validação estática, WCAG e smoke test HTTP | `validacoes-automatizadas-20261025.md` | Aprovados |

O único item deliberadamente fora desta rodada é o ensaio da apresentação. O
vídeo disponível serve apenas como apoio técnico, sem afirmar que houve ensaio
completo do roteiro.
