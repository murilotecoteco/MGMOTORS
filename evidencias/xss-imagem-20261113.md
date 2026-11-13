# Validação de arquivo de imagem — marketplace

- Data: 2026-11-13
- Ambiente: produção pública, formulário de anúncio em
  `https://mgmotorss.vercel.app/MG-MARKETPLACE/marketplace.html?anunciar=1`
- Artefato de teste: `mgmotors-xss-probe.svg`, SVG mínimo e inofensivo, sem
  dados pessoais e sem publicação de anúncio.

## Resultado observado

Ao selecionar o arquivo no campo de foto principal, a interface exibiu:

> `Tipo inválido: mgmotors-xss-probe.svg — use JPG, PNG ou WEBP.`

O formulário foi fechado sem acionar “Publicar anúncio”; logo, nenhum arquivo
foi enviado ao armazenamento e nenhum dado foi persistido. A validação no
frontend aceita apenas `image/jpeg`, `image/png` e `image/webp`, de modo que o
SVG foi recusado antes do fluxo de upload.

## Limite da evidência

O teste confirma o bloqueio visível no cliente para esse tipo de arquivo. Não
alega testar execução de script em todos os navegadores, validação do servidor
ou segurança de um arquivo que tenha passado pelo upload; isso exigiria ambiente
de staging e teste específico, sem usar dados reais.
