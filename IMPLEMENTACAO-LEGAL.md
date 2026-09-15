# Implementação — Termos de Uso e Política de Privacidade

## Objetivo

Implementar no MGMOTORS:

- Página de Termos de Uso
- Página de Política de Privacidade
- Modal de aviso no primeiro acesso
- Aceite obrigatório durante o cadastro
- Registro do aceite no Supabase
- Controle de versão dos documentos
- Proteção por RLS
- Links no footer

---

# 1. Arquitetura

Criar:

MG-LEGAL/
├── legal.html
└── legal.css

MG-LEGAL-CONSENT/
├── legal-consent.js
└── legal-consent.css

> Os documentos legais ficam separados da lógica do modal.
> O modal pode ser carregado nas páginas principais do sistema.

---

# 2. Documentos legais

## 2.1 Termos de Uso

Criar uma página contendo:

1. Sobre a MGMOTORS
2. Aceitação dos termos
3. Cadastro de usuários
4. Anúncios de veículos
5. Responsabilidade pelas informações
6. Negociação entre usuários
7. Condutas proibidas
8. Remoção de anúncios
9. Suspensão de contas
10. Propriedade intelectual
11. Limitação de responsabilidade
12. Alterações dos termos
13. Contato

## 2.2 Política de Privacidade

Criar uma página contendo:

1. Introdução
2. Dados coletados
3. Dados de cadastro
4. Dados dos anúncios
5. Imagens dos veículos
6. Finalidade do uso dos dados
7. Armazenamento
8. Segurança
9. Serviços de terceiros
10. Cookies e localStorage
11. Direitos do usuário
12. Exclusão da conta
13. Retenção dos dados
14. Alterações da política
15. Contato

---

# 3. Modal de primeiro acesso

Não utilizar `window.alert()`.

Criar um modal personalizado utilizando:

- HTML
- CSS
- JavaScript

O modal deverá informar que existem os Termos de Uso e a Política de Privacidade.

Deve possuir:

- título;
- descrição;
- link para Termos de Uso;
- link para Política de Privacidade;
- botão de continuar.

O modal deve ser responsivo.

---

# 4. Comportamento do visitante

Visitantes não autenticados podem navegar normalmente pelo marketplace.

No primeiro acesso, apresentar o aviso legal.

O usuário não deve ser impedido de navegar simplesmente por não ter criado uma conta.

Após clicar em continuar, registrar no `localStorage` que o aviso já foi exibido.

Exemplo de chave:

`legal_notice_seen`

Importante:

`localStorage` serve apenas para controlar a exibição do aviso.

Não utilizar `localStorage` como registro oficial de consentimento.

---

# 5. Cadastro

Modificar:

`MG-LOGIN/register.html`

Adicionar:

- checkbox para Termos de Uso;
- checkbox para Política de Privacidade.

Exemplo:

☐ Li e aceito os Termos de Uso

☐ Li e concordo com a Política de Privacidade

O botão de cadastro deve permanecer desabilitado enquanto os dois não estiverem marcados.

Os links devem abrir os respectivos documentos.

---

# 6. Banco de dados

Como o projeto utiliza Supabase, adicionar ao perfil do usuário:

- `terms_accepted_at`
- `privacy_accepted_at`
- `terms_version`
- `privacy_version`

Exemplo:

terms_accepted_at:
2026-09-15 12:30:00

privacy_accepted_at:
2026-09-15 12:30:00

terms_version:
1.0

privacy_version:
1.0

---

# 7. Versionamento

Definir versões atuais dos documentos.

Exemplo:

CURRENT_TERMS_VERSION = "1.0"

CURRENT_PRIVACY_VERSION = "1.0"

Quando houver alteração nos documentos, incrementar a versão.

Exemplo:

1.0 → 1.1

O sistema deve comparar:

versão aceita pelo usuário

com

versão atual do documento.

Se forem diferentes, solicitar novo aceite.

---

# 8. Fluxo de autenticação

## Novo usuário

Cadastro
↓
Aceite dos documentos
↓
Criação da conta
↓
Registro do consentimento
↓
Usuário entra no sistema

## Usuário existente

Login
↓
Verificar versão dos documentos
↓
Versão atual já aceita?
↓
SIM → continuar
NÃO → solicitar novo aceite

---

# 9. Supabase

Utilizar o Supabase como fonte de verdade para os aceites dos usuários.

Não confiar exclusivamente no frontend.

O frontend pode controlar a interface, mas o banco deve armazenar:

- usuário;
- data do aceite;
- versão dos Termos;
- versão da Política de Privacidade.

---

# 10. RLS

Atualizar:

`supabase-rls-setup.sql`

Garantir que um usuário autenticado somente possa consultar/modificar seus próprios dados.

A regra deve utilizar a relação:

`auth.uid() = profiles.id`

Nunca permitir que um usuário altere o consentimento de outro usuário.

Testar as policies utilizando usuários diferentes.

---

# 11. Footer

Adicionar em todas as páginas relevantes:

Termos de Uso | Política de Privacidade

Exemplo:

MGMOTORS

Marketplace · Dicas · Ajuda · Contato

Termos de Uso · Política de Privacidade

© 2026 MGMOTORS

---

# 12. Acessibilidade

O modal deve:

- utilizar `role="dialog"`;
- utilizar `aria-modal="true"`;
- possuir título acessível;
- permitir navegação por teclado;
- possuir foco adequado;
- possuir contraste suficiente;
- funcionar em dispositivos móveis.

---

# 13. Responsividade

Testar:

- desktop;
- notebook;
- tablet;
- celular.

O modal não deve ultrapassar a tela em dispositivos pequenos.

Utilizar largura adaptável e permitir rolagem quando o conteúdo for maior que a altura disponível.

---

# 14. Segurança

Não considerar o frontend como mecanismo de segurança.

Não confiar em:

- checkbox do HTML;
- JavaScript;
- localStorage.

O registro definitivo deve estar associado ao usuário no Supabase.

As policies do Supabase devem impedir acesso indevido aos dados.

---

# 15. Testes

## Modal

- [ ] Aparece no primeiro acesso
- [ ] Não aparece novamente após continuar
- [ ] Link para Termos funciona
- [ ] Link para Privacidade funciona
- [ ] Funciona no celular
- [ ] Funciona no desktop

## Cadastro

- [ ] Termos são obrigatórios
- [ ] Política é obrigatória
- [ ] Botão permanece desabilitado sem aceite
- [ ] Cadastro funciona após os dois aceites

## Banco

- [ ] Data do aceite é registrada
- [ ] Versão dos Termos é registrada
- [ ] Versão da Política é registrada
- [ ] Usuário não consegue alterar dados de outro usuário

## Versionamento

- [ ] Usuário com versão antiga recebe novo aviso
- [ ] Usuário com versão atual não recebe novo aceite

---

# 16. Critérios de conclusão

A implementação estará concluída quando:

- [ ] Termos de Uso estiverem publicados
- [ ] Política de Privacidade estiver publicada
- [ ] Links estiverem disponíveis no footer
- [ ] Modal estiver funcionando
- [ ] Cadastro exigir os dois aceites
- [ ] Aceites forem registrados no Supabase
- [ ] Versões forem armazenadas
- [ ] RLS estiver configurado
- [ ] Fluxo de atualização dos documentos funcionar
- [ ] Layout for responsivo
- [ ] Testes forem realizados

---

# 17. Ordem de implementação

Implementar nesta ordem:

1. Criar páginas legais
2. Criar estilos
3. Adicionar links ao footer
4. Criar modal
5. Implementar comportamento do modal
6. Adicionar checkboxes ao cadastro
7. Criar/alterar campos no banco
8. Implementar registro do aceite
9. Configurar RLS
10. Implementar versionamento
11. Testar
12. Revisar documentação

---

# Resultado esperado

O MGMOTORS deverá possuir uma implementação organizada de Termos de Uso e Política de Privacidade, com:

- documentação legal acessível;
- aviso de primeiro acesso;
- aceite explícito no cadastro;
- persistência do consentimento;
- versionamento;
- segurança através de RLS;
- experiência responsiva.