# Ambiente de desenvolvimento e testes — MG Motors

Registro das versões verificadas em **22/10/2026** para apoiar a documentação do projeto e os testes de responsividade.

## Sistema e ferramentas

| Componente | Versão/estado | Situação |
|---|---|---|
| Sistema usado na coleta | Arch Linux x86_64 | Confirmado |
| Kernel | 7.2.11-arch1-1 | Confirmado |
| Node.js | v26.12.0 | Confirmado |
| npm | 12.2.1 | Confirmado |
| VS Code | 1.142.0 (`6d62b1d5dace93a33b3a6d3eca1317bd5e15bcb1`) | Confirmado |
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
| Firefox no Arch Linux | 158.0 |
| Chromium instalado no Arch Linux | 154.0.8037.97 |
| Google Chrome no Windows 11 | 156.0.8078.47/.48 — versão estável oficial de referência em 22/10/2026 |
| Brave no Windows 11 | 1.97.57 — versão desktop oficial; Chromium 155.0.8059.80 |
| Windows | Windows 11 — confirmado pelo responsável pelos testes |
| Mobile FIRST (Firefox) | 4.20.4 |
| Tamanhos testados | Smartphone, tablet e desktop por simulador responsivo; resoluções exatas ainda precisam ser registradas |

As versões acima são as versões estáveis oficiais encontradas nas páginas dos fabricantes na data deste registro. Para comprovar a versão efetivamente instalada no computador usado na demonstração, ainda é recomendável salvar um print de `chrome://version` e `brave://version`.

## Chatling

O projeto incorpora `https://chatling.ai/js/embed.js` sem número de versão fixado no endereço. Portanto, a versão exata do widget não pode ser determinada apenas pelo código-fonte; deve ser registrada no painel do Chatling ou documentada como “widget hospedado pelo Chatling, versão não exposta no embed”.

Na consulta da página oficial de preços em 22/10/2026, o plano Free informava: 200 créditos de IA por mês, 1 agente, 1 assento, 500.000 caracteres na base de conhecimento, chats ilimitados, 25 créditos de e-mail por mês, 2 ações por agente, 1 workflow por agente, personalização limitada e upload individual de arquivo de até 1 MB. O plano Free não inclui anexos de arquivos no chat.

Fonte: [preços oficiais do Chatling](https://chatling.ai/pricing).

## Pendências para fechar o artigo

1. Confirmar com print as versões instaladas do Chrome e do Brave no computador usado.
2. Registrar as resoluções exatas dos testes e associá-las a navegador e dispositivo simulado.
3. Registrar no painel do Chatling o nome do plano e a data da consulta; a versão do widget não aparece no embed.
4. Se a banca exigir PostgreSQL local, instalar apenas o cliente `psql` ou declarar que o PostgreSQL foi utilizado exclusivamente como serviço gerenciado pelo Supabase.
