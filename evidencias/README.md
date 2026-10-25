# Evidências — MGMOTORS

Esta pasta guarda as provas de teste usadas na banca. **Nenhum arquivo aqui
substitui a execução real**: só entra evidência do que foi executado no ambiente
oficial (`https://mgmotorss.vercel.app`) ou em staging identificado.

## Estrutura sugerida

```
evidencias/
  rls-antes.txt            # saída do script de RLS antes da migration
  rls-depois.txt           # saída do script de RLS depois da migration
  xss-marketplace.png      # payload de imagem bloqueado no marketplace
  demo-*.png               # capturas do roteiro de demonstração
  ensaio-*.mp4             # vídeo do ensaio/plano B
```

## Regras

1. Nome do arquivo: `tema-ambiente-data.extensao`
   (ex.: `rls-staging-20261025.txt`).
2. Texto/log: copie a saída completa, incluindo o resumo `PASS/FAIL`.
3. Print: mostre a URL, a data do sistema e o resultado na mesma imagem.
4. Vídeo: grave a tela inteira, sem cortes entre os passos do roteiro.
5. Nunca edite um log para “corrigir” o resultado. Se falhou, registre a falha
   e a correção seguinte.
6. Não inclua token, senha, e-mail pessoal ou chave de serviço nas evidências.

## O que ainda falta

| Evidência | Status | Observação |
|---|---|---|
| RLS antes/depois | Pendente | Depende de staging e da migration aplicada |
| XSS de imagem | Pendente | Teste manual no marketplace |
| Capturas reais (Figuras 6–8) | Pendente | Depende de anúncio de teste com fotos |
| Roteiro de demo com prints | Pendente | Usar `ROTEIRO-DEMO.md` |
| Vídeo de backup | Pendente | Plano B offline |
