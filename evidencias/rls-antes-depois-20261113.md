# RLS — comparação antes/depois

## Escopo e cuidado metodológico

Esta é uma consolidação de evidências históricas, preparada em 2026-11-13. Ela
**não** afirma uma nova execução comparativa no mesmo momento: reproduzir o
estado anterior exigiria desfazer o hardening, e o roteiro de RLS possui seções
destrutivas que não devem ser usadas em produção.

| Momento | Fonte primária do registro | Resultado registrado |
|---|---|---|
| Antes do hardening, 22/10/2026 | `../ANALISE-COMPLETA-20261022.md`, seção 3.1 | 17 PASS / 4 FAIL nas seções não destrutivas `[1]–[4]` contra produção. |
| Depois do hardening, 25/10/2026 | `hardening-producao-20261025.md` | 27 PASS / 0 FAIL no verificador de hardening e 0 migrations pendentes. |

As quatro falhas históricas documentadas eram: leitura anônima de avaliações,
leitura excessiva de fotos de anúncios, execução anônima de
`promover_moderador` e execução anônima de `criar_tabela_carrinho`.

O verificador posterior confirma a presença das correções estruturais
correspondentes: RLS habilitado, remoção de SELECT público excessivo, remoção de
privilégios anônimos nas RPCs sensíveis e políticas de armazenamento por dono do
caminho. Isso é evidência de hardening aplicado, não substituto de um novo teste
funcional ponta a ponta com contas de staging.

Para uma repetição futura, usar staging descartável e registrar somente as
seções seguras `[1]–[4]` em produção; as seções `[5]–[7]` permanecem proibidas
nesse ambiente.
