-- =====================================================================
-- MG MOTORS — RLS (Row Level Security) para o Supabase — v2
-- Revisado contra o schema real (usuarios.moderador, mensagens,
-- CHECK de denuncias.status, falta de UNIQUE em avaliacoes, etc).
-- =====================================================================
-- Rode a PARTE 0 primeiro, sozinha, e me mande o resultado (ou leia
-- você mesmo) ANTES de rodar o resto. É o único jeito de saber se algum
-- trigger de contador (curtidas, seguidores) vai ser bloqueado pelas
-- policies novas.


-- =====================================================================
-- PARTE 0 — DIAGNÓSTICO (rode antes, não altera nada)
-- =====================================================================
-- anuncios.curtidas e usuarios.seguidores/seguindo claramente são
-- mantidos por trigger (o front-end só lê, nunca dá update neles).
-- Se a função do trigger NÃO for SECURITY DEFINER, ela roda com o
-- privilégio de quem disparou o INSERT/DELETE em curtidas_anuncio ou
-- seguidores — ou seja, quando fulano curte o anúncio de ciclano, o
-- UPDATE em anuncios.curtidas roda como FULANO. Como fulano não é dono
-- do anúncio, a policy de UPDATE de "anuncios" (parte 3) vai bloquear
-- esse update e o contador para de incrementar.

select
  t.trigger_name,
  t.event_object_table as tabela,
  t.action_timing,
  t.event_manipulation,
  p.proname as funcao,
  p.prosecdef as eh_security_definer   -- precisa ser "true"
from information_schema.triggers t
join pg_proc p on p.proname = regexp_replace(t.action_statement, '^EXECUTE (PROCEDURE|FUNCTION) ([a-zA-Z0-9_]+).*', '\2')
where t.trigger_schema = 'public'
order by tabela;

-- Se alguma linha relacionada a curtidas_anuncio, seguidores, ou
-- anuncios/usuarios (contadores) aparecer com eh_security_definer =
-- false, rode (trocando NOME_DA_FUNCAO):
--   alter function public.NOME_DA_FUNCAO() security definer;
-- Isso faz o trigger rodar com privilégio de dono da função em vez do
-- privilégio de quem chamou, contornando a RLS sem abrir brecha (só
-- essa função específica ganha o bypass, não o usuário).


-- =====================================================================
-- PARTE 0.5 — FIX CONFIRMADO (rodado o diagnóstico da Parte 0)
-- =====================================================================
-- atualizar_contador_seguidores roda como quem SEGUE (auth.uid() = A),
-- mas precisa atualizar a linha do usuário SEGUIDO (B) em `usuarios`
-- pra incrementar/decrementar o contador. Sem SECURITY DEFINER, a
-- policy "usuarios update proprio ou admin" da Parte 3 bloqueia esse
-- update porque A != B. Sem essa linha, seguir/deixar de seguir
-- continua gravando em `seguidores` só que o contador para de mexer,
-- silenciosamente (sem erro visível pro usuário).
alter function public.atualizar_contador_seguidores() security definer;

-- Os outros que apareceram com "false" no seu diagnóstico ficam ok sem
-- alteração: incrementar_curtidas/decrementar_curtidas já são security
-- definer (true); atualizar_conversa e criar_config_usuario escrevem
-- em conversas/config_usuario, que este script não colocou sob RLS;
-- verificar_cooldown_anuncio só precisa ler as PRÓPRIAS linhas do
-- usuário em anuncios, o que a policy de SELECT da Parte 4 já libera.


-- =====================================================================
-- PARTE 1 — LIMPEZA (caso você tenha rodado a v1 que te mandei antes)
-- =====================================================================
drop trigger if exists trg_proteger_campos_usuarios on public.usuarios;
drop function if exists public.proteger_campos_sensiveis_usuarios();
drop table if exists public.admins cascade;


-- =====================================================================
-- PARTE 2 — is_admin() usando usuarios.moderador (já existe no schema)
-- =====================================================================
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select moderador from public.usuarios where id = auth.uid()),
    false
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, anon;

-- Marca os 3 e-mails que hoje estão hardcoded no devpanel.html como
-- moderadores de verdade. Só funciona se eles já tiverem se cadastrado
-- no site (linha em public.usuarios). Rode de novo sem problema.
update public.usuarios
set moderador = true
where email in (
  'murilofrank157@gmail.com',
  'guilhermefrankadami@gmail.com',
  'candidomurilo809@gmail.com'
);


-- =====================================================================
-- PARTE 3 — USUARIOS
-- =====================================================================
alter table public.usuarios enable row level security;

drop policy if exists "usuarios select publico" on public.usuarios;
create policy "usuarios select publico"
  on public.usuarios for select
  to authenticated, anon
  using (true);

drop policy if exists "usuarios insert proprio" on public.usuarios;
create policy "usuarios insert proprio"
  on public.usuarios for insert
  to authenticated
  with check (id = auth.uid());

drop policy if exists "usuarios update proprio ou admin" on public.usuarios;
create policy "usuarios update proprio ou admin"
  on public.usuarios for update
  to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists "usuarios delete proprio ou admin" on public.usuarios;
create policy "usuarios delete proprio ou admin"
  on public.usuarios for delete
  to authenticated
  using (id = auth.uid() or public.is_admin());

-- Campos que o próprio usuário NUNCA pode alterar sozinho:
--   banido / moderador  -> só admin (senão qualquer um vira moderador)
--   nota_media / total_avaliacoes -> só o fluxo de avaliação mexe nisso
-- seguidores/seguindo NÃO entram aqui de propósito: são mantidos por
-- trigger disparado por OUTRO usuário (quem segue/deixa de seguir),
-- então travar por "is_admin()" quebraria o contador. Se depois de
-- rodar a Parte 0 os triggers de contador já forem SECURITY DEFINER,
-- dá pra travar esses dois campos aqui também — me avisa que eu ajusto.
create or replace function public.proteger_campos_sensiveis_usuarios()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    new.banido := old.banido;
    new.moderador := old.moderador;
    new.nota_media := old.nota_media;
    new.total_avaliacoes := old.total_avaliacoes;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_campos_usuarios on public.usuarios;
create trigger trg_proteger_campos_usuarios
  before update on public.usuarios
  for each row execute function public.proteger_campos_sensiveis_usuarios();


-- =====================================================================
-- PARTE 4 — ANUNCIOS
-- =====================================================================
-- status é enum (status_anuncio), usado pelo devpanel como fila de
-- moderação: 'pendente' -> 'ativo' | 'rejeitado' | 'banido'.
-- (status_moderacao, coluna text separada no schema, não é usada em
-- nenhum lugar do front-end hoje — deixei fora do escopo.)

alter table public.anuncios enable row level security;

drop policy if exists "anuncios select" on public.anuncios;
create policy "anuncios select"
  on public.anuncios for select
  to authenticated, anon
  using (
    status = 'ativo'
    or usuario_id = auth.uid()
    or public.is_admin()
  );

drop policy if exists "anuncios insert proprio" on public.anuncios;
create policy "anuncios insert proprio"
  on public.anuncios for insert
  to authenticated
  with check (usuario_id = auth.uid());

drop policy if exists "anuncios update proprio ou admin" on public.anuncios;
create policy "anuncios update proprio ou admin"
  on public.anuncios for update
  to authenticated
  using (usuario_id = auth.uid() or public.is_admin())
  with check (usuario_id = auth.uid() or public.is_admin());

drop policy if exists "anuncios delete proprio ou admin" on public.anuncios;
create policy "anuncios delete proprio ou admin"
  on public.anuncios for delete
  to authenticated
  using (usuario_id = auth.uid() or public.is_admin());

create or replace function public.proteger_status_anuncios()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_admin() then
      new.status := 'pendente';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.status is distinct from old.status and not public.is_admin() then
      new.status := old.status;
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_proteger_status_anuncios on public.anuncios;
create trigger trg_proteger_status_anuncios
  before insert or update on public.anuncios
  for each row execute function public.proteger_status_anuncios();


-- =====================================================================
-- PARTE 5 — FOTOS_ANUNCIO
-- =====================================================================
alter table public.fotos_anuncio enable row level security;

drop policy if exists "fotos_anuncio select publico" on public.fotos_anuncio;
create policy "fotos_anuncio select publico"
  on public.fotos_anuncio for select
  to authenticated, anon
  using (true);

drop policy if exists "fotos_anuncio insert dono do anuncio" on public.fotos_anuncio;
create policy "fotos_anuncio insert dono do anuncio"
  on public.fotos_anuncio for insert
  to authenticated
  with check (
    exists (select 1 from public.anuncios a where a.id = anuncio_id and a.usuario_id = auth.uid())
    or public.is_admin()
  );

drop policy if exists "fotos_anuncio delete dono do anuncio" on public.fotos_anuncio;
create policy "fotos_anuncio delete dono do anuncio"
  on public.fotos_anuncio for delete
  to authenticated
  using (
    exists (select 1 from public.anuncios a where a.id = anuncio_id and a.usuario_id = auth.uid())
    or public.is_admin()
  );


-- =====================================================================
-- PARTE 6 — DENUNCIAS
-- =====================================================================
-- Corrige o CHECK que hoje não deixa o devpanel gravar status:"resolvido"
-- (bug pré-existente, sem relação com RLS — só achei revisando o schema).
alter table public.denuncias drop constraint if exists denuncias_status_check;
alter table public.denuncias add constraint denuncias_status_check
  check (status = any (array['pendente','analisada','rejeitada','acao_tomada','resolvido']));

alter table public.denuncias enable row level security;

drop policy if exists "denuncias insert proprio" on public.denuncias;
create policy "denuncias insert proprio"
  on public.denuncias for insert
  to authenticated
  with check (denunciante_id = auth.uid());

drop policy if exists "denuncias select admin" on public.denuncias;
create policy "denuncias select admin"
  on public.denuncias for select
  to authenticated
  using (denunciante_id = auth.uid() or public.is_admin());

drop policy if exists "denuncias update admin" on public.denuncias;
create policy "denuncias update admin"
  on public.denuncias for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- =====================================================================
-- PARTE 7 — MENSAGENS  (faltou na v1 — usada em MG-MENSAGENS)
-- =====================================================================
alter table public.mensagens enable row level security;

drop policy if exists "mensagens select participante" on public.mensagens;
create policy "mensagens select participante"
  on public.mensagens for select
  to authenticated
  using (remetente_id = auth.uid() or destinatario_id = auth.uid());

drop policy if exists "mensagens insert como remetente" on public.mensagens;
create policy "mensagens insert como remetente"
  on public.mensagens for insert
  to authenticated
  with check (remetente_id = auth.uid());

-- Só o destinatário atualiza (é o "marcar como lida"). O remetente não
-- deveria poder editar mensagem já enviada.
drop policy if exists "mensagens update destinatario marca lida" on public.mensagens;
create policy "mensagens update destinatario marca lida"
  on public.mensagens for update
  to authenticated
  using (destinatario_id = auth.uid())
  with check (destinatario_id = auth.uid());

-- Trava extra: mesmo sendo o destinatario, só pode mexer no campo
-- "lida" — não pode reescrever o conteúdo da mensagem que recebeu.
create or replace function public.proteger_conteudo_mensagens()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    new.conteudo := old.conteudo;
    new.remetente_id := old.remetente_id;
    new.destinatario_id := old.destinatario_id;
    new.anuncio_id := old.anuncio_id;
    new.carro_info := old.carro_info;
    new.tipo := old.tipo;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_conteudo_mensagens on public.mensagens;
create trigger trg_proteger_conteudo_mensagens
  before update on public.mensagens
  for each row execute function public.proteger_conteudo_mensagens();


-- =====================================================================
-- PARTE 8 — CURTIDAS_ANUNCIO / SEGUIDORES / POSTS_USUARIO / AVALIACOES
-- =====================================================================
alter table public.curtidas_anuncio enable row level security;
drop policy if exists "curtidas select publico" on public.curtidas_anuncio;
create policy "curtidas select publico" on public.curtidas_anuncio for select to authenticated, anon using (true);
drop policy if exists "curtidas insert proprio" on public.curtidas_anuncio;
create policy "curtidas insert proprio" on public.curtidas_anuncio for insert to authenticated with check (usuario_id = auth.uid());
drop policy if exists "curtidas delete proprio" on public.curtidas_anuncio;
create policy "curtidas delete proprio" on public.curtidas_anuncio for delete to authenticated using (usuario_id = auth.uid());

-- evita curtida duplicada (o front faz delete-then-insert, mas sem essa
-- constraint um duplo-clique rápido pode gerar 2 linhas pro mesmo like)
alter table public.curtidas_anuncio drop constraint if exists curtidas_anuncio_unica;
alter table public.curtidas_anuncio add constraint curtidas_anuncio_unica unique (anuncio_id, usuario_id);

alter table public.seguidores enable row level security;
drop policy if exists "seguidores select publico" on public.seguidores;
create policy "seguidores select publico" on public.seguidores for select to authenticated, anon using (true);
drop policy if exists "seguidores insert proprio" on public.seguidores;
create policy "seguidores insert proprio" on public.seguidores for insert to authenticated with check (seguidor_id = auth.uid());
drop policy if exists "seguidores delete proprio" on public.seguidores;
create policy "seguidores delete proprio" on public.seguidores for delete to authenticated using (seguidor_id = auth.uid());

alter table public.posts_usuario enable row level security;
drop policy if exists "posts select publico" on public.posts_usuario;
create policy "posts select publico" on public.posts_usuario for select to authenticated, anon using (true);
drop policy if exists "posts insert proprio" on public.posts_usuario;
create policy "posts insert proprio" on public.posts_usuario for insert to authenticated with check (usuario_id = auth.uid());
drop policy if exists "posts delete proprio ou admin" on public.posts_usuario;
create policy "posts delete proprio ou admin" on public.posts_usuario for delete to authenticated using (usuario_id = auth.uid() or public.is_admin());

-- avaliacoes.upsert(onConflict: "avaliador_id,avaliado_id") no
-- conta.html precisa dessa constraint pra funcionar — sem ela o upsert
-- já falha hoje, antes de qualquer RLS.
alter table public.avaliacoes drop constraint if exists avaliacoes_avaliador_avaliado_unica;
alter table public.avaliacoes add constraint avaliacoes_avaliador_avaliado_unica unique (avaliador_id, avaliado_id);

alter table public.avaliacoes enable row level security;
drop policy if exists "avaliacoes select publico" on public.avaliacoes;
create policy "avaliacoes select publico" on public.avaliacoes for select to authenticated, anon using (true);
drop policy if exists "avaliacoes insert proprio" on public.avaliacoes;
create policy "avaliacoes insert proprio" on public.avaliacoes for insert to authenticated with check (avaliador_id = auth.uid() and avaliador_id <> avaliado_id);
drop policy if exists "avaliacoes update proprio" on public.avaliacoes;
create policy "avaliacoes update proprio" on public.avaliacoes for update to authenticated using (avaliador_id = auth.uid()) with check (avaliador_id = auth.uid() and avaliador_id <> avaliado_id);


-- =====================================================================
-- PARTE 9 — CARRINHO_ITENS (100% privado)
-- =====================================================================
alter table public.carrinho_itens enable row level security;
drop policy if exists "carrinho select proprio" on public.carrinho_itens;
create policy "carrinho select proprio" on public.carrinho_itens for select to authenticated using (usuario_id = auth.uid());
drop policy if exists "carrinho insert proprio" on public.carrinho_itens;
create policy "carrinho insert proprio" on public.carrinho_itens for insert to authenticated with check (usuario_id = auth.uid());
drop policy if exists "carrinho delete proprio" on public.carrinho_itens;
create policy "carrinho delete proprio" on public.carrinho_itens for delete to authenticated using (usuario_id = auth.uid());


-- =====================================================================
-- PARTE 10 — MARCAS / MODELOS (referência, leitura pública)
-- =====================================================================
alter table public.marcas enable row level security;
drop policy if exists "marcas select publico" on public.marcas;
create policy "marcas select publico" on public.marcas for select to authenticated, anon using (true);

alter table public.modelos enable row level security;
drop policy if exists "modelos select publico" on public.modelos;
create policy "modelos select publico" on public.modelos for select to authenticated, anon using (true);


-- =====================================================================
-- FORA DO ESCOPO DESTE SCRIPT (schema tem, front-end não usa hoje):
--   versoes, opcionais, anuncios_opcionais, favoritos (é localStorage,
--   não banco), propostas, conversas (calculada a partir de mensagens),
--   curtidas_post, config_usuario, usuarios_banidos.
-- Continuam sem RLS = abertas, do jeito que já estavam. Não pioram nem
-- melhoram com este script. Se algum dia o front passar a usar alguma
-- delas, me chama que eu faço a policy.
--
-- CHECKLIST antes de considerar concluído:
--   [ ] Rodar PARTE 0 e confirmar (ou corrigir) SECURITY DEFINER nos
--       triggers de contador — SEM ISSO, curtir/seguir de outra conta
--       vai parecer que "funciona" na tela mas o contador trava.
--   [ ] Logar com e-mail comum e confirmar que devpanel.html nega acesso.
--   [ ] Logar com um dos 3 e-mails admin e testar aprovar/rejeitar
--       anúncio, banir/desbanir usuário, resolver denúncia.
--   [ ] Testar fluxo normal: cadastro, criar anúncio, pausar/despausar,
--       curtir, seguir, avaliar, carrinho, denunciar, mensagens.
--   [ ] Bucket de Storage (FOTOS-ANUNCIOS) precisa de policy própria —
--       não é coberto por este script. Aviso se quiser que eu monte.
-- =====================================================================
