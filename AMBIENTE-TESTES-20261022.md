# Ambiente de desenvolvimento e testes — MG Motors

Registro das versões verificadas em **25/10/2026** para apoiar a documentação do projeto e os testes de responsividade.

## Sistema e ferramentas

| Componente | Versão/estado | Situação |
|---|---|---|
| Sistema usado na coleta | Arch Linux x86_64 | Confirmado |
| Kernel | 7.2.11-arch1-1 | Confirmado |
| Node.js | v26.12.0 | Confirmado |
| npm | 12.2.1 | Confirmado |
| VS Code | 1.143.1 (`e646868227c3e3a9e3f24277c8c7220be42c0be7`) | Confirmado |
| Supabase CLI | 2.117.0 | Confirmado |
| PostgreSQL no computador | Cliente `psql` não instalado | Não disponível localmente |
| PostgreSQL no Supabase | 17.6 | Confirmado pelo painel do projeto |
| Plano Supabase | Free | Confirmado pelo painel do projeto |

## Extensões relevantes do VS Code

| Extensão | Versão |
|---|---:|
| Live Server — `ritwickdey.liveserver` | 5.7.10 |
| Python — `ms-python.python` | 2026.10.0 |
| Pylance — `ms-python.vscode-pylance` | 2026.4.1 |
| Python Debugger — `ms-python.debugpy` | 2026.6.0 |
| Python Environments — `ms-python.vscode-python-envs` | 1.40.0 |
| GitHub Pull Requests — `github.vscode-pull-request-github` | 0.172.0 |
| GitHub Actions — `github.vscode-github-actions` | 0.32.3 |
| Remote Containers — `ms-vscode-remote.remote-containers` | 0.469.0 |
| Containers — `ms-azuretools.vscode-containers` | 2.5.3 |
| Gitless — `maattdd.gitless` | 11.7.2 |
| Dart — `dart-code.dart-code` | 3.144.0 |
| Flutter — `dart-code.flutter` | 3.144.0 |
| Language Pack Português — `ms-ceintl.vscode-language-pack-pt-br` | 1.131.2026090407 |

## Navegadores e responsividade

| Navegador/dispositivo | Versão/estado |
|---|---|
| Firefox no Arch Linux | 158.0.1 |
| Chromium instalado no Arch Linux | 156.0.8078.47 |
| Google Chrome/Brave | Não instalados neste ambiente de coleta |
| Windows | Utilizado em testes anteriores, sem versão coletada neste registro |
| Redmi 13C | 1600 × 720 — navbar responsiva observada |
| Samsung A35 | 1080 × 2340 — navbar responsiva observada |

As versões dos navegadores acima são as versões efetivamente instaladas no Arch Linux durante a coleta. Os testes móveis foram registrados pelos modelos e resoluções informados pelo responsável pelo projeto.

## Chatling

O projeto incorpora `https://chatling.ai/js/embed.js` sem número de versão fixado no endereço. Portanto, a versão exata do widget não pode ser determinada apenas pelo código-fonte; deve ser registrada no painel do Chatling ou documentada como “widget hospedado pelo Chatling, versão não exposta no embed”.

Na consulta da página oficial de preços em 22/10/2026, o plano Free informava: 200 créditos de IA por mês, 1 agente, 1 assento, 500.000 caracteres na base de conhecimento, chats ilimitados, 25 créditos de e-mail por mês, 2 ações por agente, 1 workflow por agente, personalização limitada e upload individual de arquivo de até 1 MB. O plano Free não inclui anexos de arquivos no chat.

Fonte: [preços oficiais do Chatling](https://chatling.ai/pricing).

## Pendências para fechar o artigo

1. Registrar no painel do Chatling o nome do plano e a data da consulta; a versão do widget não aparece no embed.
2. Se a banca exigir PostgreSQL local, instalar apenas o cliente `psql` ou declarar que o PostgreSQL foi utilizado exclusivamente como serviço gerenciado pelo Supabase.
