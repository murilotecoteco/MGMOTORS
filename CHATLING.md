# Chatling — registro para a banca

**Consulta do painel:** 13/11/2026
**Widget no código:** `chatbotId: "3965249523"`
**Script:** `https://chatling.ai/js/embed.js`

> Registro de configuração e avaliação exploratória. Ele não transforma a
> resposta do provedor em garantia jurídica de conformidade com a LGPD.

## 1. Configuração confirmada no painel

| Item | Situação observada |
|---|---|
| Provedor | Chatling, por widget hospedado |
| Plano | Free |
| Modelo selecionado | GPT-6.1 Sol; painel indica 5 créditos por resposta |
| Limite do plano Free | 200 créditos de IA/mês, 1 agente, 1 assento e 500.000 caracteres na base de conhecimento |
| Base configurada | 5 fontes, todas processadas; 36.541 caracteres no total |
| Respostas limitadas à base | Opção “Limit answers to knowledge base” habilitada |
| Anexos pelo chat | Desabilitados e indisponíveis no plano atual |
| Retenção configurável | Indisponível no plano Free; não há período personalizado configurado no painel |
| Versão do widget | Não exposta pelo embed nem pelo painel consultado |

As fontes processadas eram:

1. `Como Utilizar – MG Motors | Guia Completo` — 23.121 caracteres;
2. `Dicas e Ajuda - MG Motors | Compre e Venda com Segurança` — 8.281 caracteres;
3. `Contato - MG Motors | Fale Conosco` — 715 caracteres;
4. `Encontros de Carros - MG Motors | Marque e participe` — 214 caracteres;
5. texto `MG MOTORS — SEGURANÇA, CONTA, PRIVACIDADE E USO DA PLATAFORMA` — 4.210 caracteres.

As fontes 1 a 4 apontam para páginas públicas da MGMOTORS; a quinta é uma
fonte textual de orientação sobre conta, segurança, privacidade e negociações.

## 2. Avaliação exploratória no ambiente publicado

Em 13/11/2026, foram feitas cinco perguntas ao widget publicado e registradas
no artigo (Figuras 10 a 14):

| Pergunta | Resultado observado |
|---|---|
| Como recuperar a senha? | Orientou o uso de “Esqueci minha senha”, o e-mail de recuperação e a checagem de spam/link. |
| O login é seguro? | Explicou HTTPS, Supabase Auth e boas práticas; não prometeu risco zero. |
| Como funciona reembolso? | Informou que a plataforma é marketplace e não processa o pagamento; não inventou política de devolução. |
| Como denunciar anúncio suspeito? | Indicou o recurso de denúncia e recomendou não transferir dinheiro nem dados. |
| Devo compartilhar senha ou código? | Respondeu que não; a plataforma não deve pedir senha ou código de recuperação. |

O resultado demonstra aderência inicial às fontes e às instruções do agente.
Não substitui estudo de usabilidade, amostra externa, teste de cobertura da base
ou avaliação de segurança do fornecedor.

## 3. Privacidade, treinamento e limites de declaração

- Os [Termos de Serviço do Chatling](https://chatling.ai/terms-of-service)
  declaram que provedores de modelo não usam as fontes nem as entradas e saídas
  do chatbot para treinar seus modelos. Trata-se de declaração contratual do
  provedor, não de auditoria independente.
- A [Política de Privacidade](https://chatling.ai/privacy-policy) descreve
  tratamento e retenção geral enquanto necessários às finalidades e à conta.
  Como o painel não disponibiliza retenção personalizada no Free, não há prazo
  específico configurado para a MGMOTORS.
- A página de [preços do Chatling](https://chatling.ai/pricing) é a referência
  para limites comerciais, que podem ser alterados pelo fornecedor. Conferir o
  saldo de créditos próximo à banca.

## 4. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Créditos acabarem antes da banca | Conferir o saldo antes da apresentação e conservar o vídeo público de apoio. |
| Serviço indisponível | Explicar o fluxo principal sem depender do chatbot e usar as capturas/evidências como plano B. |
| Resposta inadequada | Manter as respostas limitadas à base, revisar as fontes e não tratar o chatbot como canal decisório. |
| Dúvida sobre LGPD | Distinguir o que foi configurado, a declaração do fornecedor e a validação jurídica que ainda não foi realizada. |

## 5. Checklist para o dia da banca

- [x] Plano, modelo, fontes e limitações verificados no painel.
- [x] Cinco perguntas exploratórias registradas no artigo.
- [x] Retenção identificada como recurso indisponível no plano atual.
- [x] Vídeo público de apoio gerado em `evidencias/videos/`.
- [ ] Conferir saldo de créditos e disponibilidade do widget no dia da apresentação.
