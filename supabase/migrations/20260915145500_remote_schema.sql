SET local check_function_bodies = off;

CREATE TABLE "public"."anuncios_opcionais" (
  "anuncio_id"  uuid                     NOT NULL,
  "opcional_id" uuid                     NOT NULL,
  "criado_em"   timestamp with time zone DEFAULT now(),
  CONSTRAINT "anuncios_opcionais_pkey" PRIMARY KEY (anuncio_id, opcional_id)
);

ALTER TABLE "public"."anuncios_opcionais"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."anuncios" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "usuario_id"       uuid                     NOT NULL,
  "marca_id"         uuid,
  "modelo_id"        uuid,
  "versao_id"        uuid,
  "titulo"           text                     DEFAULT 'Anúncio de Veículo'::text,
  "descricao"        text,
  "preco"            numeric(12,2)            NOT NULL,
  "ano_fabricacao"   integer                  NOT NULL,
  "ano_modelo"       integer                  NOT NULL,
  "quilometragem"    integer                  NOT NULL,
  "cor"              text,
  "final_placa"      character(1),
  "cep"              text,
  "cidade"           text                     NOT NULL,
  "estado"           character(2)             NOT NULL,
  "whatsapp"         text,
  "visualizacoes"    integer                  NOT NULL DEFAULT 0,
  "criado_em"        timestamp with time zone DEFAULT now(),
  "atualizado_em"    timestamp with time zone DEFAULT now(),
  "curtidas"         integer                  DEFAULT 0,
  "ultimo_anuncio"   timestamp with time zone,
  "latitude"         double precision,
  "longitude"        double precision,
  "cidade_display"   text,
  "data_venda"       timestamp with time zone,
  "status_moderacao" text                     DEFAULT 'pendente'::text,
  "pausado"          boolean                  DEFAULT false,
  "tipo_veiculo"     text                     DEFAULT 'carro'::text,
  "modelo_texto"     text,
  "marca_texto"      text,
  "horas_motor"      integer,
  CONSTRAINT "anuncios_pkey" PRIMARY KEY (id),
  CONSTRAINT "anuncios_preco_check" CHECK ((preco > (0)::numeric)),
  CONSTRAINT "anuncios_quilometragem_check" CHECK ((quilometragem >= 0)),
  CONSTRAINT "anuncios_tipo_veiculo_check"
    CHECK ((tipo_veiculo = ANY (ARRAY['carro'::text, 'caminhao'::text, 'moto'::text, 'utilitario'::text, 'embarcacao'::text, 'maquina_agricola'::text, 'onibus'::text]))),
  CONSTRAINT "chk_estado_valido" CHECK ((estado ~ '^[A-Z]{2}$'::text)),
  CONSTRAINT "chk_final_placa" CHECK (((final_placa IS NULL) OR (final_placa ~ '^[0-9]$'::text)))
);

ALTER TABLE "public"."anuncios"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."avaliacoes" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "avaliador_id" uuid                     NOT NULL,
  "avaliado_id"  uuid                     NOT NULL,
  "nota"         integer,
  "comentario"   text,
  "criado_em"    timestamp with time zone DEFAULT now(),
  CONSTRAINT "avaliacoes_avaliador_avaliado_unica" UNIQUE (avaliador_id, avaliado_id),
  CONSTRAINT "avaliacoes_avaliador_id_avaliado_id_key" UNIQUE (avaliador_id, avaliado_id),
  CONSTRAINT "avaliacoes_nota_check" CHECK (((nota >= 1) AND (nota <= 5))),
  CONSTRAINT "avaliacoes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."avaliacoes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."carrinho_itens" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "usuario_id" uuid                     NOT NULL,
  "anuncio_id" uuid                     NOT NULL,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "carrinho_itens_pkey" PRIMARY KEY (id),
  CONSTRAINT "carrinho_itens_usuario_id_anuncio_id_key" UNIQUE (usuario_id, anuncio_id)
);

ALTER TABLE "public"."carrinho_itens"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."comunidade_comentarios" (
  "id"        uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "post_id"   uuid                     NOT NULL,
  "user_id"   uuid                     NOT NULL,
  "texto"     text                     NOT NULL,
  "criado_em" timestamp with time zone DEFAULT now(),
  CONSTRAINT "comunidade_comentarios_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."comunidade_comentarios"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."comunidade_curtidas" (
  "post_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  CONSTRAINT "comunidade_curtidas_pkey" PRIMARY KEY (post_id, user_id)
);

ALTER TABLE "public"."comunidade_curtidas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."comunidade_posts_fotos" (
  "id"      uuid    NOT NULL DEFAULT gen_random_uuid(),
  "post_id" uuid    NOT NULL,
  "url"     text    NOT NULL,
  "ordem"   integer DEFAULT 0,
  CONSTRAINT "comunidade_posts_fotos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."comunidade_posts_fotos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."comunidade_posts" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "veiculo_id" uuid,
  "tipo"       text                     DEFAULT 'foto'::text,
  "legenda"    text,
  "curtidas"   integer                  DEFAULT 0,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "comunidade_posts_pkey" PRIMARY KEY (id),
  CONSTRAINT "comunidade_posts_tipo_check" CHECK ((tipo = ANY (ARRAY['foto'::text, 'restauracao'::text, 'modificacao'::text, 'viagem'::text, 'outro'::text])))
);

ALTER TABLE "public"."comunidade_posts"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."config_usuario" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "usuario_id"         uuid                     NOT NULL,
  "tema"               text                     DEFAULT 'claro'::text,
  "notificacoes_email" boolean                  DEFAULT true,
  "notificacoes_site"  boolean                  DEFAULT true,
  "privacidade_perfil" text                     DEFAULT 'publico'::text,
  "atualizado_em"      timestamp with time zone DEFAULT now(),
  CONSTRAINT "config_usuario_pkey" PRIMARY KEY (id),
  CONSTRAINT "config_usuario_usuario_id_key" UNIQUE (usuario_id)
);

ALTER TABLE "public"."config_usuario"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."conversas" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "usuario1_id"          uuid,
  "usuario2_id"          uuid,
  "anuncio_id"           uuid,
  "carro_info"           text,
  "ultima_mensagem"      text,
  "ultima_mensagem_data" timestamp with time zone DEFAULT now(),
  "criado_em"            timestamp with time zone DEFAULT now(),
  CONSTRAINT "conversas_pkey" PRIMARY KEY (id),
  CONSTRAINT "conversas_usuario1_id_usuario2_id_anuncio_id_key" UNIQUE (usuario1_id, usuario2_id, anuncio_id)
);

ALTER TABLE "public"."conversas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."curtidas_anuncio" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "anuncio_id" uuid                     NOT NULL,
  "usuario_id" uuid                     NOT NULL,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "curtidas_anuncio_anuncio_id_usuario_id_key" UNIQUE (anuncio_id, usuario_id),
  CONSTRAINT "curtidas_anuncio_pkey" PRIMARY KEY (id),
  CONSTRAINT "curtidas_anuncio_unica" UNIQUE (anuncio_id, usuario_id)
);

ALTER TABLE "public"."curtidas_anuncio"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."curtidas_post" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "post_id"    uuid                     NOT NULL,
  "usuario_id" uuid                     NOT NULL,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "curtidas_post_pkey" PRIMARY KEY (id),
  CONSTRAINT "curtidas_post_post_id_usuario_id_key" UNIQUE (post_id, usuario_id)
);

ALTER TABLE "public"."curtidas_post"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."denuncias" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "denunciante_id" uuid                     NOT NULL,
  "tipo"           text                     NOT NULL,
  "alvo_id"        uuid                     NOT NULL,
  "motivo"         text                     NOT NULL,
  "descricao"      text,
  "status"         text                     DEFAULT 'pendente'::text,
  "criado_em"      timestamp with time zone DEFAULT now(),
  "resolvido_em"   timestamp with time zone,
  "resolvido_por"  uuid,
  CONSTRAINT "denuncias_pkey" PRIMARY KEY (id),
  CONSTRAINT "denuncias_status_check" CHECK ((status = ANY (ARRAY['pendente'::text, 'analisada'::text, 'rejeitada'::text, 'acao_tomada'::text, 'resolvido'::text]))),
  CONSTRAINT "denuncias_tipo_check" CHECK ((tipo = ANY (ARRAY['anuncio'::text, 'perfil'::text])))
);

ALTER TABLE "public"."denuncias"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."encontros_confirmados" (
  "encontro_id"   uuid                     NOT NULL,
  "user_id"       uuid                     NOT NULL,
  "confirmado_em" timestamp with time zone DEFAULT now(),
  CONSTRAINT "encontros_confirmados_pkey" PRIMARY KEY (encontro_id, user_id)
);

ALTER TABLE "public"."encontros_confirmados"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."encontros" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "criador_id"   uuid,
  "nome"         text                     NOT NULL,
  "descricao"    text,
  "regras"       text,
  "requisitos"   text,
  "tipo_veiculo" text                     DEFAULT 'todos'::text,
  "data"         date                     NOT NULL,
  "hora"         time without time zone,
  "local_nome"   text,
  "cidade"       text,
  "estado"       character(2),
  "lat"          numeric(10,7),
  "lng"          numeric(10,7),
  "ativo"        boolean                  DEFAULT true,
  "criado_em"    timestamp with time zone DEFAULT now(),
  "status"       text                     DEFAULT 'approved'::text,
  "veiculo_id"   uuid,
  CONSTRAINT "encontros_pkey" PRIMARY KEY (id),
  CONSTRAINT "encontros_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))),
  CONSTRAINT "encontros_tipo_veiculo_check"
    CHECK ((tipo_veiculo = ANY (ARRAY['todos'::text, 'antigos'::text, 'jdm'::text, 'esportivos'::text, 'muscle'::text, 'eletricos'::text, 'motos'::text])))
);

ALTER TABLE "public"."encontros"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."favoritos" (
  "usuario_id" uuid                     NOT NULL,
  "anuncio_id" uuid                     NOT NULL,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "favoritos_pkey" PRIMARY KEY (usuario_id, anuncio_id)
);

ALTER TABLE "public"."favoritos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."fotos_anuncio" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "anuncio_id" uuid                     NOT NULL,
  "url_foto"   text                     NOT NULL,
  "ordem"      integer                  NOT NULL DEFAULT 0,
  "caminho"    text,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "fotos_anuncio_pkey" PRIMARY KEY (id),
  CONSTRAINT "unique_foto_por_anuncio_ordem" UNIQUE (anuncio_id, ordem)
);

ALTER TABLE "public"."fotos_anuncio"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."garagem_fotos" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "veiculo_id" uuid                     NOT NULL,
  "url"        text                     NOT NULL,
  "legenda"    text,
  "criado_em"  timestamp with time zone DEFAULT now(),
  "path"       text,
  "ordem"      integer                  DEFAULT 0,
  CONSTRAINT "garagem_fotos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."garagem_fotos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."garagem_gastos" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "veiculo_id" uuid                     NOT NULL,
  "categoria"  text                     NOT NULL,
  "descricao"  text,
  "valor"      numeric(10,2)            NOT NULL,
  "data"       date                     NOT NULL,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "garagem_gastos_categoria_check" CHECK ((categoria = ANY (ARRAY['manutencao'::text, 'combustivel'::text, 'seguro'::text, 'ipva'::text, 'peca'::text, 'outro'::text]))),
  CONSTRAINT "garagem_gastos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."garagem_gastos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."garagem_lembretes" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "veiculo_id"    uuid                     NOT NULL,
  "titulo"        text                     NOT NULL,
  "data_prevista" date,
  "km_prevista"   integer,
  "concluido"     boolean                  DEFAULT false,
  "criado_em"     timestamp with time zone DEFAULT now(),
  CONSTRAINT "garagem_lembretes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."garagem_lembretes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."garagem_manutencoes" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "veiculo_id"       uuid                     NOT NULL,
  "tipo"             text                     NOT NULL,
  "descricao"        text,
  "data"             date                     NOT NULL,
  "km_na_manutencao" integer,
  "custo"            numeric(10,2),
  "oficina"          text,
  "observacoes"      text,
  "criado_em"        timestamp with time zone DEFAULT now(),
  CONSTRAINT "garagem_manutencoes_pkey" PRIMARY KEY (id),
  CONSTRAINT "garagem_manutencoes_tipo_check" CHECK ((tipo = ANY (ARRAY['oleo'::text, 'pneu'::text, 'revisao'::text, 'peca'::text, 'outro'::text])))
);

ALTER TABLE "public"."garagem_manutencoes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."garagem_veiculos" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"        uuid                     NOT NULL,
  "marca"          text                     NOT NULL,
  "modelo"         text                     NOT NULL,
  "ano"            integer,
  "versao"         text,
  "cor"            text,
  "km_atual"       integer                  DEFAULT 0,
  "foto_principal" text,
  "ativo"          boolean                  DEFAULT true,
  "criado_em"      timestamp with time zone DEFAULT now(),
  "motor"          text,
  "cambio"         text,
  "combustivel"    text,
  "potencia"       integer,
  CONSTRAINT "garagem_veiculos_cambio_check" CHECK ((cambio = ANY (ARRAY['manual'::text, 'automatico'::text, 'cvt'::text, 'automatizado'::text]))),
  CONSTRAINT "garagem_veiculos_combustivel_check"
    CHECK ((combustivel = ANY (ARRAY['flex'::text, 'gasolina'::text, 'etanol'::text, 'diesel'::text, 'eletrico'::text, 'hibrido'::text, 'gnv'::text]))),
  CONSTRAINT "garagem_veiculos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."garagem_veiculos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."marcas" (
  "id"        uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "nome"      text                     NOT NULL,
  "criado_em" timestamp with time zone DEFAULT now(),
  "categoria" text                     DEFAULT 'carro'::text,
  CONSTRAINT "marcas_nome_key" UNIQUE (nome),
  CONSTRAINT "marcas_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."marcas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."mensagens" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "remetente_id"    uuid,
  "destinatario_id" uuid,
  "anuncio_id"      uuid,
  "conteudo"        text                     NOT NULL,
  "carro_info"      text,
  "lida"            boolean                  DEFAULT false,
  "data_envio"      timestamp with time zone DEFAULT now(),
  "criado_em"       timestamp with time zone DEFAULT now(),
  "tipo"            text                     DEFAULT 'texto'::text,
  CONSTRAINT "mensagens_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."mensagens"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modelos" (
  "id"        uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "marca_id"  uuid                     NOT NULL,
  "nome"      text                     NOT NULL,
  "criado_em" timestamp with time zone DEFAULT now(),
  CONSTRAINT "modelos_pkey" PRIMARY KEY (id),
  CONSTRAINT "unique_modelo_por_marca" UNIQUE (marca_id, nome)
);

ALTER TABLE "public"."modelos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."opcionais" (
  "id"        uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "nome"      text                     NOT NULL,
  "tipo"      text,
  "criado_em" timestamp with time zone DEFAULT now(),
  CONSTRAINT "opcionais_nome_key" UNIQUE (nome),
  CONSTRAINT "opcionais_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."opcionais"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."posts_usuario" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "usuario_id" uuid                     NOT NULL,
  "imagem"     text                     NOT NULL,
  "legenda"    text,
  "curtidas"   integer                  DEFAULT 0,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "posts_usuario_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."posts_usuario"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."projetos_atualizacoes_fotos" (
  "id"             uuid    NOT NULL DEFAULT gen_random_uuid(),
  "atualizacao_id" uuid    NOT NULL,
  "url"            text    NOT NULL,
  "ordem"          integer DEFAULT 0,
  CONSTRAINT "projetos_atualizacoes_fotos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."projetos_atualizacoes_fotos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."projetos_atualizacoes" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "projeto_id" uuid                     NOT NULL,
  "titulo"     text                     NOT NULL,
  "descricao"  text,
  "etapa"      text,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "projetos_atualizacoes_etapa_check" CHECK ((etapa = ANY (ARRAY['antes'::text, 'durante'::text, 'depois'::text]))),
  CONSTRAINT "projetos_atualizacoes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."projetos_atualizacoes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."projetos_comentarios" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "projeto_id" uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "texto"      text                     NOT NULL,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "projetos_comentarios_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."projetos_comentarios"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."projetos_curtidas" (
  "projeto_id" uuid NOT NULL,
  "user_id"    uuid NOT NULL,
  CONSTRAINT "projetos_curtidas_pkey" PRIMARY KEY (projeto_id, user_id)
);

ALTER TABLE "public"."projetos_curtidas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."projetos" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "veiculo_id" uuid,
  "nome"       text                     NOT NULL,
  "descricao"  text,
  "status"     text                     DEFAULT 'em_andamento'::text,
  "curtidas"   integer                  DEFAULT 0,
  "criado_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "projetos_pkey" PRIMARY KEY (id),
  CONSTRAINT "projetos_status_check" CHECK ((status = ANY (ARRAY['em_andamento'::text, 'concluido'::text, 'pausado'::text])))
);

ALTER TABLE "public"."projetos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."propostas" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "anuncio_id"     uuid                     NOT NULL,
  "comprador_id"   uuid                     NOT NULL,
  "vendedor_id"    uuid                     NOT NULL,
  "mensagem"       text                     NOT NULL,
  "valor_proposta" numeric(12,2),
  "criado_em"      timestamp with time zone DEFAULT now(),
  CONSTRAINT "propostas_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."propostas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."seguidores" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "seguidor_id" uuid                     NOT NULL,
  "seguido_id"  uuid                     NOT NULL,
  "criado_em"   timestamp with time zone DEFAULT now(),
  CONSTRAINT "seguidores_pkey" PRIMARY KEY (id),
  CONSTRAINT "seguidores_seguidor_id_seguido_id_key" UNIQUE (seguidor_id, seguido_id)
);

ALTER TABLE "public"."seguidores"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."usuarios_banidos" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "usuario_id" uuid                     NOT NULL,
  "motivo"     text                     NOT NULL,
  "banido_por" uuid,
  "banido_em"  timestamp with time zone DEFAULT now(),
  CONSTRAINT "usuarios_banidos_pkey" PRIMARY KEY (id),
  CONSTRAINT "usuarios_banidos_usuario_id_key" UNIQUE (usuario_id)
);

ALTER TABLE "public"."usuarios_banidos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."usuarios" (
  "id"               uuid                     NOT NULL,
  "email"            text,
  "nome"             text,
  "foto"             text,
  "idade"            integer,
  "cidade"           text,
  "estado"           text,
  "telefone"         text,
  "bio"              text,
  "criado_em"        timestamp with time zone DEFAULT now(),
  "atualizado_em"    timestamp with time zone DEFAULT now(),
  "capa_foto"        text,
  "data_nascimento"  date,
  "site"             text,
  "instagram"        text,
  "seguidores"       integer                  DEFAULT 0,
  "seguindo"         integer                  DEFAULT 0,
  "bloqueado"        boolean                  DEFAULT false,
  "moderador"        boolean                  DEFAULT false,
  "banido"           boolean                  DEFAULT false,
  "preferencias"     jsonb                    DEFAULT '{}'::jsonb,
  "nota_media"       numeric(3,2)             DEFAULT 0,
  "total_avaliacoes" integer                  DEFAULT 0,
  "is_admin"         boolean                  DEFAULT false,
  CONSTRAINT "usuarios_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."usuarios"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."versoes" (
  "id"        uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "modelo_id" uuid                     NOT NULL,
  "nome"      text                     NOT NULL,
  "criado_em" timestamp with time zone DEFAULT now(),
  CONSTRAINT "unique_versao_por_modelo" UNIQUE (modelo_id, nome),
  CONSTRAINT "versoes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."versoes"
  ENABLE ROW LEVEL SECURITY;

CREATE TYPE "public"."status_anuncio" AS ENUM (
  'ativo',
  'pendente',
  'vendido',
  'expirado'
);

ALTER TABLE "public"."anuncios"
  ADD COLUMN "status" public.status_anuncio NOT NULL DEFAULT 'ativo'::public.status_anuncio;

CREATE TYPE "public"."status_proposta" AS ENUM (
  'pendente',
  'aceita',
  'recusada',
  'cancelada'
);

ALTER TABLE "public"."propostas"
  ADD COLUMN "status" public.status_proposta DEFAULT 'pendente'::public.status_proposta;

CREATE TYPE "public"."tipo_cambio" AS ENUM (
  'manual',
  'automatico',
  'automatizado'
);

ALTER TABLE "public"."anuncios"
  ADD COLUMN "cambio" public.tipo_cambio;

CREATE TYPE "public"."tipo_combustivel" AS ENUM (
  'gasolina',
  'alcool',
  'flex',
  'diesel',
  'eletrico',
  'hibrido'
);

ALTER TABLE "public"."anuncios"
  ADD COLUMN "combustivel" public.tipo_combustivel;

CREATE OR REPLACE FUNCTION public.admin_atualizar_usuario (
  p_email            text,
  p_moderador        boolean DEFAULT NULL::boolean,
  p_banido           boolean DEFAULT NULL::boolean,
  p_nota_media       numeric DEFAULT NULL::numeric,
  p_total_avaliacoes integer DEFAULT NULL::integer
)
  RETURNS public.usuarios
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  resultado public.usuarios;
begin
  alter table public.usuarios disable trigger trg_proteger_campos_usuarios;

  update public.usuarios
  set
    moderador        = coalesce(p_moderador, moderador),
    banido           = coalesce(p_banido, banido),
    nota_media       = coalesce(p_nota_media, nota_media),
    total_avaliacoes = coalesce(p_total_avaliacoes, total_avaliacoes)
  where email = p_email
  returning * into resultado;

  alter table public.usuarios enable trigger trg_proteger_campos_usuarios;

  if resultado.id is null then
    raise notice 'Nenhum usuário encontrado com email %', p_email;
  end if;

  return resultado;
exception when others then
  -- garante que o trigger volta a ligar mesmo se o update falhar
  alter table public.usuarios enable trigger trg_proteger_campos_usuarios;
  raise;
end;
$function$;

CREATE OR REPLACE FUNCTION public.atualizar_contador_seguidores()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE usuarios SET seguidores = COALESCE(seguidores, 0) + 1 WHERE id = NEW.seguido_id;
        UPDATE usuarios SET seguindo = COALESCE(seguindo, 0) + 1 WHERE id = NEW.seguidor_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE usuarios SET seguidores = COALESCE(seguidores, 0) - 1 WHERE id = OLD.seguido_id;
        UPDATE usuarios SET seguindo = COALESCE(seguindo, 0) - 1 WHERE id = OLD.seguidor_id;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.atualizar_conversa()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
DECLARE
    u1 UUID;
    u2 UUID;
BEGIN
    u1 := LEAST(NEW.remetente_id, NEW.destinatario_id);
    u2 := GREATEST(NEW.remetente_id, NEW.destinatario_id);
    INSERT INTO conversas (usuario1_id, usuario2_id, anuncio_id, carro_info, ultima_mensagem, ultima_mensagem_data)
    VALUES (u1, u2, NEW.anuncio_id, NEW.carro_info, NEW.conteudo, NEW.data_envio)
    ON CONFLICT (usuario1_id, usuario2_id, anuncio_id)
    DO UPDATE SET ultima_mensagem = NEW.conteudo, ultima_mensagem_data = NEW.data_envio;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.checar_cooldown_anuncio()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  ultimo_anuncio TIMESTAMPTZ;
  segundos_passados NUMERIC;
BEGIN
  SELECT MAX(criado_em) INTO ultimo_anuncio
  FROM public.anuncios
  WHERE usuario_id = NEW.usuario_id;

  IF ultimo_anuncio IS NOT NULL THEN
    segundos_passados := EXTRACT(EPOCH FROM (NOW() - ultimo_anuncio));
    IF segundos_passados < 15 THEN
      RAISE EXCEPTION 'Aguarde % segundos antes de publicar outro anúncio.', CEIL(15 - segundos_passados);
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.criar_config_usuario()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
    INSERT INTO config_usuario (usuario_id, tema) VALUES (NEW.id, 'claro')
    ON CONFLICT (usuario_id) DO NOTHING;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.criar_tabela_carrinho()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
    CREATE TABLE IF NOT EXISTS carrinho_itens (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        usuario_id uuid REFERENCES usuarios(id) ON DELETE CASCADE NOT NULL,
        anuncio_id uuid REFERENCES anuncios(id) ON DELETE CASCADE NOT NULL,
        criado_em timestamp DEFAULT now(),
        UNIQUE(usuario_id, anuncio_id)
    );

    ALTER TABLE carrinho_itens ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Usuarios gerenciam seus carrinhos" ON carrinho_itens;
    CREATE POLICY "Usuarios gerenciam seus carrinhos" ON carrinho_itens FOR ALL USING (auth.uid() = usuario_id);
    
    -- Força reload do schema
    NOTIFY pgrst, 'reload schema';
END;
$function$;

CREATE OR REPLACE FUNCTION public.decrementar_curtidas()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
    UPDATE anuncios SET curtidas = GREATEST(COALESCE(curtidas, 0) - 1, 0) WHERE id = OLD.anuncio_id;
    RETURN OLD;
END;
$function$;

CREATE OR REPLACE FUNCTION public.decrementar_curtidas_anuncio()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
    UPDATE anuncios SET curtidas = curtidas - 1 WHERE id = OLD.anuncio_id;
    RETURN OLD;
END;
$function$;

CREATE OR REPLACE FUNCTION public.decrementar_curtidas_post()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
    UPDATE posts_usuario SET curtidas = curtidas - 1 WHERE id = OLD.post_id;
    RETURN OLD;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_anuncios_marketplace (
  usuario_id_param uuid DEFAULT NULL::uuid
)
  RETURNS TABLE (
    id             uuid,
    usuario_id     uuid,
    marca_id       uuid,
    modelo_id      uuid,
    preco          numeric,
    ano_fabricacao integer,
    ano_modelo     integer,
    quilometragem  integer,
    cor            text,
    cidade         text,
    estado         text,
    cidade_display text,
    status         text,
    curtidas       integer,
    pausado        boolean,
    latitude       double precision,
    longitude      double precision,
    criado_em      timestamp with time zone,
    marca_nome     text,
    modelo_nome    text,
    marca_texto    text,
    modelo_texto   text,
    foto_principal text,
    vendedor_foto  text,
    usuario_curtiu boolean,
    tipo_veiculo   text
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  RETURN QUERY
  SELECT
    a.id,
    a.usuario_id,
    a.marca_id,
    a.modelo_id,
    a.preco,
    a.ano_fabricacao,
    a.ano_modelo,
    a.quilometragem,
    a.cor,
    a.cidade,
    a.estado::text,
    a.cidade_display,
    a.status::text,
    a.curtidas,
    a.pausado,
    a.latitude,
    a.longitude,
    a.criado_em,
    marc.nome    AS marca_nome,
    mod.nome     AS modelo_nome,
    a.marca_texto,
    a.modelo_texto,
    (
      SELECT fa.url_foto
      FROM public.fotos_anuncio fa
      WHERE fa.anuncio_id = a.id
      ORDER BY fa.ordem ASC
      LIMIT 1
    ) AS foto_principal,
    u.foto       AS vendedor_foto,
    CASE
      WHEN usuario_id_param IS NULL THEN FALSE
      ELSE EXISTS(
        SELECT 1
        FROM public.curtidas_anuncio ca
        WHERE ca.anuncio_id = a.id
          AND ca.usuario_id = usuario_id_param
      )
    END AS usuario_curtiu,
    COALESCE(a.tipo_veiculo, 'carro') AS tipo_veiculo
  FROM public.anuncios a
  LEFT JOIN public.marcas marc ON marc.id = a.marca_id
  LEFT JOIN public.modelos mod  ON mod.id  = a.modelo_id
  LEFT JOIN public.usuarios u   ON u.id    = a.usuario_id
  WHERE a.status = 'ativo'
    AND (a.pausado = FALSE OR a.pausado IS NULL)
  ORDER BY a.criado_em DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  INSERT INTO public.usuarios (id, email, nome)
  VALUES (
    new.id,
    new.email,
    COALESCE(
      new.raw_user_meta_data->>'nome',
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$function$;

CREATE OR REPLACE FUNCTION public.incrementar_curtidas()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
    UPDATE anuncios SET curtidas = COALESCE(curtidas, 0) + 1 WHERE id = NEW.anuncio_id;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.incrementar_curtidas_anuncio()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
    UPDATE anuncios SET curtidas = curtidas + 1 WHERE id = NEW.anuncio_id;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.incrementar_curtidas_post()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
    UPDATE posts_usuario SET curtidas = curtidas + 1 WHERE id = NEW.post_id;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    (select moderador from public.usuarios where id = auth.uid()),
    false
  );
$function$;

CREATE OR REPLACE FUNCTION public.limpar_dependencias_antes_excluir_anuncio()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  delete from public.mensagens        where anuncio_id = old.id;
  delete from public.curtidas_anuncio where anuncio_id = old.id;
  delete from public.fotos_anuncio    where anuncio_id = old.id;
  -- Limpa denúncias feitas sobre esse anúncio (tipo='anuncio' e alvo_id = id
  -- do anúncio). Sem isso não bloqueia o delete (alvo_id é polimórfico, sem
  -- FK de verdade), mas fica lixo referenciando um anúncio que não existe
  -- mais e pode confundir a tela de denúncias do MG-DEV.
  delete from public.denuncias where tipo = 'anuncio' and alvo_id = old.id;
  return old;
end;
$function$;

CREATE OR REPLACE FUNCTION public.promover_moderador (
  p_email text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  -- Se foi chamada por alguém autenticado via API que NÃO é admin,
  -- barra aqui (dupla proteção, além do fix do trigger acima).
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Apenas administradores podem promover moderadores.';
  end if;

  update public.usuarios
  set moderador = true
  where email = p_email;
end;
$function$;

CREATE OR REPLACE FUNCTION public.proteger_campos_sensiveis_usuarios()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.is_admin() then
    new.banido := old.banido;
    new.moderador := old.moderador;
    new.nota_media := old.nota_media;
    new.total_avaliacoes := old.total_avaliacoes;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.proteger_conteudo_mensagens()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.proteger_status_anuncios()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.verificar_cooldown_anuncio()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  ultimo_anuncio timestamptz;
  segundos_restantes numeric;
begin
  -- Admin/moderador pode publicar sem cooldown (útil pra teste e suporte)
  if public.is_admin() then
    return new;
  end if;

  select max(criado_em) into ultimo_anuncio
  from public.anuncios
  where usuario_id = new.usuario_id;

  if ultimo_anuncio is not null and now() - ultimo_anuncio < interval '15 seconds' then
    segundos_restantes := ceil(extract(epoch from (interval '15 seconds' - (now() - ultimo_anuncio))));
    raise exception 'Aguarde % segundos antes de publicar outro anúncio.', segundos_restantes;
  end if;

  return new;
end;
$function$;

ALTER TABLE "public"."anuncios_opcionais"
  ADD CONSTRAINT "anuncios_opcionais_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."carrinho_itens"
  ADD CONSTRAINT "carrinho_itens_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_comentarios"
  ADD CONSTRAINT "comunidade_comentarios_post_id_fkey" FOREIGN KEY (post_id) REFERENCES public.comunidade_posts(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_curtidas"
  ADD CONSTRAINT "comunidade_curtidas_post_id_fkey" FOREIGN KEY (post_id) REFERENCES public.comunidade_posts(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_posts_fotos"
  ADD CONSTRAINT "comunidade_posts_fotos_post_id_fkey" FOREIGN KEY (post_id) REFERENCES public.comunidade_posts(id) ON DELETE CASCADE;

ALTER TABLE "public"."conversas"
  ADD CONSTRAINT "conversas_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."curtidas_anuncio"
  ADD CONSTRAINT "curtidas_anuncio_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."encontros_confirmados"
  ADD CONSTRAINT "encontros_confirmados_encontro_id_fkey" FOREIGN KEY (encontro_id) REFERENCES public.encontros(id) ON DELETE CASCADE;

ALTER TABLE "public"."favoritos"
  ADD CONSTRAINT "favoritos_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."fotos_anuncio"
  ADD CONSTRAINT "fotos_anuncio_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_posts"
  ADD CONSTRAINT "comunidade_posts_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE SET NULL;

ALTER TABLE "public"."encontros"
  ADD CONSTRAINT "encontros_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE SET NULL;

ALTER TABLE "public"."garagem_fotos"
  ADD CONSTRAINT "garagem_fotos_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE CASCADE;

ALTER TABLE "public"."garagem_gastos"
  ADD CONSTRAINT "garagem_gastos_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE CASCADE;

ALTER TABLE "public"."garagem_lembretes"
  ADD CONSTRAINT "garagem_lembretes_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE CASCADE;

ALTER TABLE "public"."garagem_manutencoes"
  ADD CONSTRAINT "garagem_manutencoes_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE CASCADE;

ALTER TABLE "public"."marcas"
  ADD CONSTRAINT "marcas_categoria_check" CHECK ((categoria = ANY (ARRAY['carro'::text, 'moto'::text, 'caminhao'::text, 'trator'::text, 'embarcacao'::text]))) NOT VALID;

ALTER TABLE "public"."anuncios"
  ADD CONSTRAINT "anuncios_marca_id_fkey" FOREIGN KEY (marca_id) REFERENCES public.marcas(id);

ALTER TABLE "public"."mensagens"
  ADD CONSTRAINT "mensagens_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."modelos"
  ADD CONSTRAINT "modelos_marca_id_fkey" FOREIGN KEY (marca_id) REFERENCES public.marcas(id) ON DELETE CASCADE;

ALTER TABLE "public"."anuncios"
  ADD CONSTRAINT "anuncios_modelo_id_fkey" FOREIGN KEY (modelo_id) REFERENCES public.modelos(id);

ALTER TABLE "public"."anuncios_opcionais"
  ADD CONSTRAINT "anuncios_opcionais_opcional_id_fkey" FOREIGN KEY (opcional_id) REFERENCES public.opcionais(id) ON DELETE CASCADE;

ALTER TABLE "public"."curtidas_post"
  ADD CONSTRAINT "curtidas_post_post_id_fkey" FOREIGN KEY (post_id) REFERENCES public.posts_usuario(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos"
  ADD CONSTRAINT "projetos_veiculo_id_fkey" FOREIGN KEY (veiculo_id) REFERENCES public.garagem_veiculos(id) ON DELETE SET NULL;

ALTER TABLE "public"."projetos_atualizacoes"
  ADD CONSTRAINT "projetos_atualizacoes_projeto_id_fkey" FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos_atualizacoes_fotos"
  ADD CONSTRAINT "projetos_atualizacoes_fotos_atualizacao_id_fkey" FOREIGN KEY (atualizacao_id) REFERENCES public.projetos_atualizacoes(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos_comentarios"
  ADD CONSTRAINT "projetos_comentarios_projeto_id_fkey" FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos_curtidas"
  ADD CONSTRAINT "projetos_curtidas_projeto_id_fkey" FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE "public"."propostas"
  ADD CONSTRAINT "propostas_anuncio_id_fkey" FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE "public"."anuncios"
  ADD CONSTRAINT "anuncios_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."avaliacoes"
  ADD CONSTRAINT "avaliacoes_avaliado_id_fkey" FOREIGN KEY (avaliado_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."avaliacoes"
  ADD CONSTRAINT "avaliacoes_avaliador_id_fkey" FOREIGN KEY (avaliador_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."carrinho_itens"
  ADD CONSTRAINT "carrinho_itens_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_comentarios"
  ADD CONSTRAINT "comunidade_comentarios_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_curtidas"
  ADD CONSTRAINT "comunidade_curtidas_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."comunidade_posts"
  ADD CONSTRAINT "comunidade_posts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."config_usuario"
  ADD CONSTRAINT "config_usuario_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."conversas"
  ADD CONSTRAINT "conversas_usuario1_id_fkey" FOREIGN KEY (usuario1_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."conversas"
  ADD CONSTRAINT "conversas_usuario2_id_fkey" FOREIGN KEY (usuario2_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."curtidas_anuncio"
  ADD CONSTRAINT "curtidas_anuncio_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."curtidas_post"
  ADD CONSTRAINT "curtidas_post_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."denuncias"
  ADD CONSTRAINT "denuncias_denunciante_id_fkey" FOREIGN KEY (denunciante_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."denuncias"
  ADD CONSTRAINT "denuncias_resolvido_por_fkey" FOREIGN KEY (resolvido_por) REFERENCES public.usuarios(id);

ALTER TABLE "public"."encontros"
  ADD CONSTRAINT "encontros_criador_id_fkey" FOREIGN KEY (criador_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;

ALTER TABLE "public"."encontros_confirmados"
  ADD CONSTRAINT "encontros_confirmados_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."favoritos"
  ADD CONSTRAINT "favoritos_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."garagem_veiculos"
  ADD CONSTRAINT "garagem_veiculos_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."mensagens"
  ADD CONSTRAINT "mensagens_destinatario_id_fkey" FOREIGN KEY (destinatario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."mensagens"
  ADD CONSTRAINT "mensagens_remetente_id_fkey" FOREIGN KEY (remetente_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."posts_usuario"
  ADD CONSTRAINT "posts_usuario_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos"
  ADD CONSTRAINT "projetos_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos_comentarios"
  ADD CONSTRAINT "projetos_comentarios_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."projetos_curtidas"
  ADD CONSTRAINT "projetos_curtidas_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."propostas"
  ADD CONSTRAINT "propostas_comprador_id_fkey" FOREIGN KEY (comprador_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."propostas"
  ADD CONSTRAINT "propostas_vendedor_id_fkey" FOREIGN KEY (vendedor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."seguidores"
  ADD CONSTRAINT "seguidores_seguido_id_fkey" FOREIGN KEY (seguido_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."seguidores"
  ADD CONSTRAINT "seguidores_seguidor_id_fkey" FOREIGN KEY (seguidor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."usuarios_banidos"
  ADD CONSTRAINT "usuarios_banidos_banido_por_fkey" FOREIGN KEY (banido_por) REFERENCES public.usuarios(id);

ALTER TABLE "public"."usuarios_banidos"
  ADD CONSTRAINT "usuarios_banidos_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;

ALTER TABLE "public"."versoes"
  ADD CONSTRAINT "versoes_modelo_id_fkey" FOREIGN KEY (modelo_id) REFERENCES public.modelos(id) ON DELETE CASCADE;

ALTER TABLE "public"."anuncios"
  ADD CONSTRAINT "anuncios_versao_id_fkey" FOREIGN KEY (versao_id) REFERENCES public.versoes(id);

CREATE INDEX idx_anuncios_ano_modelo ON public.anuncios USING btree (ano_modelo);

CREATE INDEX idx_anuncios_cidade_estado ON public.anuncios USING btree (cidade, estado);

CREATE INDEX idx_anuncios_cidade ON public.anuncios USING btree (cidade);

CREATE INDEX idx_anuncios_curtidas ON public.anuncios USING btree (curtidas DESC);

CREATE INDEX idx_anuncios_estado ON public.anuncios USING btree (estado);

CREATE INDEX idx_anuncios_marca ON public.anuncios USING btree (marca_id);

CREATE INDEX idx_anuncios_modelo ON public.anuncios USING btree (modelo_id);

CREATE INDEX idx_anuncios_pausado ON public.anuncios USING btree (pausado);

CREATE INDEX idx_anuncios_preco ON public.anuncios USING btree (preco);

CREATE INDEX idx_anuncios_quilometragem ON public.anuncios USING btree (quilometragem);

CREATE INDEX idx_anuncios_status_criado ON public.anuncios USING btree (status, criado_em DESC);

CREATE INDEX idx_anuncios_status_curtidas ON public.anuncios USING btree (status, curtidas DESC);

CREATE INDEX idx_anuncios_status ON public.anuncios USING btree (status);

CREATE INDEX idx_anuncios_tipo_veiculo ON public.anuncios USING btree (tipo_veiculo);

CREATE INDEX idx_anuncios_ultimo ON public.anuncios USING btree (ultimo_anuncio DESC);

CREATE INDEX idx_anuncios_usuario ON public.anuncios USING btree (usuario_id);

CREATE INDEX idx_config_usuario ON public.config_usuario USING btree (usuario_id);

CREATE INDEX idx_conversas_ultima_data ON public.conversas USING btree (ultima_mensagem_data);

CREATE INDEX idx_conversas_usuario1 ON public.conversas USING btree (usuario1_id);

CREATE INDEX idx_conversas_usuario2 ON public.conversas USING btree (usuario2_id);

CREATE INDEX idx_curtidas_anuncio ON public.curtidas_anuncio USING btree (anuncio_id);

CREATE INDEX idx_curtidas_unique ON public.curtidas_anuncio USING btree (anuncio_id, usuario_id);

CREATE INDEX idx_curtidas_usuario ON public.curtidas_anuncio USING btree (usuario_id);

CREATE INDEX idx_denuncias_status ON public.denuncias USING btree (status);

CREATE INDEX idx_denuncias_tipo ON public.denuncias USING btree (tipo);

CREATE INDEX idx_fotos_anuncio ON public.fotos_anuncio USING btree (anuncio_id);

CREATE INDEX idx_mensagens_data_envio ON public.mensagens USING btree (data_envio);

CREATE INDEX idx_mensagens_destinatario ON public.mensagens USING btree (destinatario_id);

CREATE INDEX idx_mensagens_remetente ON public.mensagens USING btree (remetente_id);

CREATE INDEX idx_posts_usuario_criado ON public.posts_usuario USING btree (usuario_id, criado_em DESC);

CREATE INDEX idx_posts_usuario_curtidas ON public.posts_usuario USING btree (curtidas DESC);

CREATE INDEX idx_posts_usuario_data ON public.posts_usuario USING btree (criado_em DESC);

CREATE INDEX idx_propostas_comprador ON public.propostas USING btree (comprador_id);

CREATE INDEX idx_propostas_vendedor ON public.propostas USING btree (vendedor_id);

CREATE INDEX idx_usuarios_banido ON public.usuarios USING btree (banido)
  WHERE (banido = true);

CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER trg_cooldown_anuncio
  BEFORE INSERT ON public.anuncios
  FOR EACH ROW
  EXECUTE FUNCTION public.checar_cooldown_anuncio();

CREATE TRIGGER trg_limpar_dependencias_anuncio
  BEFORE DELETE ON public.anuncios
  FOR EACH ROW
  EXECUTE FUNCTION public.limpar_dependencias_antes_excluir_anuncio();

CREATE TRIGGER trg_proteger_status_anuncios
  BEFORE INSERT OR UPDATE ON public.anuncios
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_status_anuncios();

CREATE TRIGGER trigger_cooldown_anuncio
  BEFORE INSERT ON public.anuncios
  FOR EACH ROW
  EXECUTE FUNCTION public.verificar_cooldown_anuncio();

CREATE TRIGGER update_anuncios_timestamp
  BEFORE UPDATE ON public.anuncios
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_curtidas_delete
  AFTER DELETE ON public.curtidas_anuncio
  FOR EACH ROW
  EXECUTE FUNCTION public.decrementar_curtidas();

CREATE TRIGGER trigger_curtidas_insert
  AFTER INSERT ON public.curtidas_anuncio
  FOR EACH ROW
  EXECUTE FUNCTION public.incrementar_curtidas();

CREATE TRIGGER trigger_curtidas_post_delete
  AFTER DELETE ON public.curtidas_post
  FOR EACH ROW
  EXECUTE FUNCTION public.decrementar_curtidas_post();

CREATE TRIGGER trigger_curtidas_post_insert
  AFTER INSERT ON public.curtidas_post
  FOR EACH ROW
  EXECUTE FUNCTION public.incrementar_curtidas_post();

CREATE TRIGGER atualizar_conversa_trigger
  AFTER INSERT ON public.mensagens
  FOR EACH ROW
  EXECUTE FUNCTION public.atualizar_conversa();

CREATE TRIGGER trg_proteger_conteudo_mensagens
  BEFORE UPDATE ON public.mensagens
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_conteudo_mensagens();

CREATE TRIGGER trigger_seguidores
  AFTER INSERT OR DELETE ON public.seguidores
  FOR EACH ROW
  EXECUTE FUNCTION public.atualizar_contador_seguidores();

CREATE TRIGGER trg_proteger_campos_usuarios
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_campos_sensiveis_usuarios();

CREATE TRIGGER trigger_criar_config
  AFTER INSERT ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.criar_config_usuario();

CREATE TRIGGER update_usuarios_timestamp
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE POLICY "Todos veem anuncios ativos" ON "public"."anuncios"
  FOR SELECT
  TO PUBLIC
  USING ((((status = 'ativo'::public.status_anuncio) AND ((pausado IS NULL) OR (pausado = false))) OR (auth.uid() = usuario_id)));

CREATE POLICY "Usuarios atualizam anuncios" ON "public"."anuncios"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = usuario_id))
  WITH CHECK ((auth.uid() = usuario_id));

CREATE POLICY "Usuarios criam anuncios" ON "public"."anuncios"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = usuario_id));

CREATE POLICY "Usuarios deletam anuncios" ON "public"."anuncios"
  FOR DELETE
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "anuncios delete proprio ou admin" ON "public"."anuncios"
  FOR DELETE
  TO "authenticated"
  USING (((usuario_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "anuncios insert proprio" ON "public"."anuncios"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((usuario_id = auth.uid()));

CREATE POLICY "anuncios select" ON "public"."anuncios"
  FOR SELECT
  TO "anon", "authenticated"
  USING (((status = 'ativo'::public.status_anuncio) OR (usuario_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "anuncios update proprio ou admin" ON "public"."anuncios"
  FOR UPDATE
  TO "authenticated"
  USING (((usuario_id = auth.uid()) OR public.is_admin()))
  WITH CHECK (((usuario_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "Todos veem opcionais de anuncios ativos" ON "public"."anuncios_opcionais"
  FOR SELECT
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.status = 'ativo'::public.status_anuncio))));

CREATE POLICY "Usuarios gerenciam opcionais dos seus anuncios" ON "public"."anuncios_opcionais"
  FOR ALL
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))))
  WITH CHECK ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))));

CREATE POLICY "Avaliacoes visíveis" ON "public"."avaliacoes"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Usuarios avaliar" ON "public"."avaliacoes"
  FOR ALL
  TO PUBLIC
  USING ((auth.uid() = avaliador_id));

CREATE POLICY "avaliacoes insert proprio" ON "public"."avaliacoes"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((avaliador_id = auth.uid()) AND (avaliador_id <> avaliado_id)));

CREATE POLICY "avaliacoes select publico" ON "public"."avaliacoes"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "avaliacoes update proprio" ON "public"."avaliacoes"
  FOR UPDATE
  TO "authenticated"
  USING ((avaliador_id = auth.uid()))
  WITH CHECK (((avaliador_id = auth.uid()) AND (avaliador_id <> avaliado_id)));

CREATE POLICY "carrinho delete proprio" ON "public"."carrinho_itens"
  FOR DELETE
  TO "authenticated"
  USING ((usuario_id = auth.uid()));

CREATE POLICY "carrinho insert proprio" ON "public"."carrinho_itens"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((usuario_id = auth.uid()));

CREATE POLICY "carrinho select proprio" ON "public"."carrinho_itens"
  FOR SELECT
  TO "authenticated"
  USING ((usuario_id = auth.uid()));

CREATE POLICY "cc_insert" ON "public"."comunidade_comentarios"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "cc_select" ON "public"."comunidade_comentarios"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "ccurt_all" ON "public"."comunidade_curtidas"
  FOR ALL
  TO PUBLIC
  USING (true)
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "cp_delete" ON "public"."comunidade_posts"
  FOR DELETE
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "cp_insert" ON "public"."comunidade_posts"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "cp_select" ON "public"."comunidade_posts"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "cpf_insert" ON "public"."comunidade_posts_fotos"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (true);

CREATE POLICY "cpf_select" ON "public"."comunidade_posts_fotos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "config_own" ON "public"."config_usuario"
  FOR ALL
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "usuarios_atualizam_conversas" ON "public"."conversas"
  FOR UPDATE
  TO PUBLIC
  USING (((auth.uid() = usuario1_id) OR (auth.uid() = usuario2_id)));

CREATE POLICY "usuarios_criam_conversas" ON "public"."conversas"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((auth.uid() = usuario1_id) OR (auth.uid() = usuario2_id)));

CREATE POLICY "usuarios_veem_conversas" ON "public"."conversas"
  FOR SELECT
  TO PUBLIC
  USING (((auth.uid() = usuario1_id) OR (auth.uid() = usuario2_id)));

CREATE POLICY "usuarios_veem_suas_conversas" ON "public"."conversas"
  FOR SELECT
  TO PUBLIC
  USING (((auth.uid() = usuario1_id) OR (auth.uid() = usuario2_id)));

CREATE POLICY "Curtidas visíveis" ON "public"."curtidas_anuncio"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Dono do anuncio apaga curtidas do anuncio" ON "public"."curtidas_anuncio"
  FOR DELETE
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))));

CREATE POLICY "Usuarios curtir" ON "public"."curtidas_anuncio"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = usuario_id));

CREATE POLICY "Usuarios descurtir" ON "public"."curtidas_anuncio"
  FOR DELETE
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "curtidas delete dono do anuncio" ON "public"."curtidas_anuncio"
  FOR DELETE
  TO "authenticated"
  USING (((usuario_id = auth.uid()) OR (anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid())))));

CREATE POLICY "curtidas delete proprio" ON "public"."curtidas_anuncio"
  FOR DELETE
  TO "authenticated"
  USING ((usuario_id = auth.uid()));

CREATE POLICY "curtidas insert proprio" ON "public"."curtidas_anuncio"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((usuario_id = auth.uid()));

CREATE POLICY "curtidas select publico" ON "public"."curtidas_anuncio"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "Usuarios gerenciam curtidas de posts" ON "public"."curtidas_post"
  FOR ALL
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "Usuarios gerenciam curtidas posts" ON "public"."curtidas_post"
  FOR ALL
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "Denuncias criar" ON "public"."denuncias"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = denunciante_id));

CREATE POLICY "denuncias insert proprio" ON "public"."denuncias"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((denunciante_id = auth.uid()));

CREATE POLICY "denuncias select admin" ON "public"."denuncias"
  FOR SELECT
  TO "authenticated"
  USING (((denunciante_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "denuncias update admin" ON "public"."denuncias"
  FOR UPDATE
  TO "authenticated"
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "enc_insert" ON "public"."encontros"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((auth.uid() IS NOT NULL) AND (criador_id = auth.uid())));

CREATE POLICY "enc_select" ON "public"."encontros"
  FOR SELECT
  TO PUBLIC
  USING ((((ativo = true) AND (status = 'approved'::text)) OR (criador_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "enc_update" ON "public"."encontros"
  FOR UPDATE
  TO PUBLIC
  USING ((criador_id = auth.uid()));

CREATE POLICY "conf_delete" ON "public"."encontros_confirmados"
  FOR DELETE
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "conf_insert" ON "public"."encontros_confirmados"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "conf_select" ON "public"."encontros_confirmados"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Usuarios gerenciam favoritos" ON "public"."favoritos"
  FOR ALL
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "Todos veem fotos anuncio" ON "public"."fotos_anuncio"
  FOR SELECT
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE ((anuncios.status = 'ativo'::public.status_anuncio) OR (anuncios.usuario_id = auth.uid())))));

CREATE POLICY "Usuarios atualizam fotos anuncio" ON "public"."fotos_anuncio"
  FOR UPDATE
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))))
  WITH CHECK ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))));

CREATE POLICY "Usuarios deletam fotos anuncio" ON "public"."fotos_anuncio"
  FOR DELETE
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))));

CREATE POLICY "Usuarios inserem fotos anuncio" ON "public"."fotos_anuncio"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))));

CREATE POLICY "fotos_anuncio delete dono do anuncio" ON "public"."fotos_anuncio"
  FOR DELETE
  TO "authenticated"
  USING (((EXISTS ( SELECT 1
   FROM public.anuncios a
  WHERE ((a.id = fotos_anuncio.anuncio_id) AND (a.usuario_id = auth.uid())))) OR public.is_admin()));

CREATE POLICY "fotos_anuncio insert dono do anuncio" ON "public"."fotos_anuncio"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((EXISTS ( SELECT 1
   FROM public.anuncios a
  WHERE ((a.id = fotos_anuncio.anuncio_id) AND (a.usuario_id = auth.uid())))) OR public.is_admin()));

CREATE POLICY "fotos_anuncio select publico" ON "public"."fotos_anuncio"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "gf_delete" ON "public"."garagem_fotos"
  FOR DELETE
  TO PUBLIC
  USING ((veiculo_id IN ( SELECT garagem_veiculos.id
   FROM public.garagem_veiculos
  WHERE (garagem_veiculos.user_id = auth.uid()))));

CREATE POLICY "gf_insert" ON "public"."garagem_fotos"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((veiculo_id IN ( SELECT garagem_veiculos.id
   FROM public.garagem_veiculos
  WHERE (garagem_veiculos.user_id = auth.uid()))));

CREATE POLICY "gf_select" ON "public"."garagem_fotos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "gfotos_all" ON "public"."garagem_fotos"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.garagem_veiculos v
  WHERE ((v.id = garagem_fotos.veiculo_id) AND (v.user_id = auth.uid())))));

CREATE POLICY "gastos_all" ON "public"."garagem_gastos"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.garagem_veiculos v
  WHERE ((v.id = garagem_gastos.veiculo_id) AND (v.user_id = auth.uid())))));

CREATE POLICY "lembretes_all" ON "public"."garagem_lembretes"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.garagem_veiculos v
  WHERE ((v.id = garagem_lembretes.veiculo_id) AND (v.user_id = auth.uid())))));

CREATE POLICY "manut_all" ON "public"."garagem_manutencoes"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.garagem_veiculos v
  WHERE ((v.id = garagem_manutencoes.veiculo_id) AND (v.user_id = auth.uid())))));

CREATE POLICY "garagem_delete" ON "public"."garagem_veiculos"
  FOR DELETE
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "garagem_insert" ON "public"."garagem_veiculos"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "garagem_select" ON "public"."garagem_veiculos"
  FOR SELECT
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "garagem_update" ON "public"."garagem_veiculos"
  FOR UPDATE
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "marcas select publico" ON "public"."marcas"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "Dono do anuncio apaga mensagens do anuncio" ON "public"."mensagens"
  FOR DELETE
  TO PUBLIC
  USING ((anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid()))));

CREATE POLICY "Usuarios atualizam mensagens" ON "public"."mensagens"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = destinatario_id));

CREATE POLICY "Usuarios enviam mensagens" ON "public"."mensagens"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = remetente_id));

CREATE POLICY "Usuarios veem suas mensagens" ON "public"."mensagens"
  FOR SELECT
  TO PUBLIC
  USING (((auth.uid() = remetente_id) OR (auth.uid() = destinatario_id)));

CREATE POLICY "mensagens delete dono do anuncio" ON "public"."mensagens"
  FOR DELETE
  TO "authenticated"
  USING (((remetente_id = auth.uid()) OR (destinatario_id = auth.uid()) OR (anuncio_id IN ( SELECT anuncios.id
   FROM public.anuncios
  WHERE (anuncios.usuario_id = auth.uid())))));

CREATE POLICY "mensagens insert como remetente" ON "public"."mensagens"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((remetente_id = auth.uid()));

CREATE POLICY "mensagens select participante" ON "public"."mensagens"
  FOR SELECT
  TO "authenticated"
  USING (((remetente_id = auth.uid()) OR (destinatario_id = auth.uid())));

CREATE POLICY "mensagens update destinatario marca lida" ON "public"."mensagens"
  FOR UPDATE
  TO "authenticated"
  USING ((destinatario_id = auth.uid()))
  WITH CHECK ((destinatario_id = auth.uid()));

CREATE POLICY "modelos select publico" ON "public"."modelos"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "Todos veem opcionais" ON "public"."opcionais"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Todos veem posts" ON "public"."posts_usuario"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Usuarios criam posts" ON "public"."posts_usuario"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = usuario_id));

CREATE POLICY "Usuarios deletam posts" ON "public"."posts_usuario"
  FOR DELETE
  TO PUBLIC
  USING ((auth.uid() = usuario_id));

CREATE POLICY "posts delete proprio ou admin" ON "public"."posts_usuario"
  FOR DELETE
  TO "authenticated"
  USING (((usuario_id = auth.uid()) OR public.is_admin()));

CREATE POLICY "posts insert proprio" ON "public"."posts_usuario"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((usuario_id = auth.uid()));

CREATE POLICY "posts select publico" ON "public"."posts_usuario"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "proj_delete" ON "public"."projetos"
  FOR DELETE
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "proj_insert" ON "public"."projetos"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "proj_select" ON "public"."projetos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "proj_update" ON "public"."projetos"
  FOR UPDATE
  TO PUBLIC
  USING ((user_id = auth.uid()));

CREATE POLICY "patu_insert" ON "public"."projetos_atualizacoes"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.projetos p
  WHERE ((p.id = projetos_atualizacoes.projeto_id) AND (p.user_id = auth.uid())))));

CREATE POLICY "patu_select" ON "public"."projetos_atualizacoes"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "pafoto_insert" ON "public"."projetos_atualizacoes_fotos"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (true);

CREATE POLICY "pafoto_select" ON "public"."projetos_atualizacoes_fotos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "pcomt_insert" ON "public"."projetos_comentarios"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "pcomt_select" ON "public"."projetos_comentarios"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "pcurt_all" ON "public"."projetos_curtidas"
  FOR ALL
  TO PUBLIC
  USING (true)
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "Envolvidos veem propostas" ON "public"."propostas"
  FOR ALL
  TO PUBLIC
  USING (((auth.uid() = comprador_id) OR (auth.uid() = vendedor_id)));

CREATE POLICY "Seguidores visíveis" ON "public"."seguidores"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Usuarios desseguir" ON "public"."seguidores"
  FOR DELETE
  TO PUBLIC
  USING ((auth.uid() = seguidor_id));

CREATE POLICY "Usuarios seguir" ON "public"."seguidores"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((auth.uid() = seguidor_id));

CREATE POLICY "seguidores delete proprio" ON "public"."seguidores"
  FOR DELETE
  TO "authenticated"
  USING ((seguidor_id = auth.uid()));

CREATE POLICY "seguidores insert proprio" ON "public"."seguidores"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((seguidor_id = auth.uid()));

CREATE POLICY "seguidores select publico" ON "public"."seguidores"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "Sistema cria usuarios" ON "public"."usuarios"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (true);

CREATE POLICY "Todos veem usuarios" ON "public"."usuarios"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Usuarios deletam sua conta" ON "public"."usuarios"
  FOR DELETE
  TO PUBLIC
  USING ((auth.uid() = id));

CREATE POLICY "Usuarios editam seu perfil" ON "public"."usuarios"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "usuarios delete proprio ou admin" ON "public"."usuarios"
  FOR DELETE
  TO "authenticated"
  USING (((id = auth.uid()) OR public.is_admin()));

CREATE POLICY "usuarios insert proprio" ON "public"."usuarios"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((id = auth.uid()));

CREATE POLICY "usuarios select publico" ON "public"."usuarios"
  FOR SELECT
  TO "anon", "authenticated"
  USING (true);

CREATE POLICY "usuarios update proprio ou admin" ON "public"."usuarios"
  FOR UPDATE
  TO "authenticated"
  USING (((id = auth.uid()) OR public.is_admin()))
  WITH CHECK (((id = auth.uid()) OR public.is_admin()));

CREATE POLICY "usuarios_banidos admin all" ON "public"."usuarios_banidos"
  FOR ALL
  TO "authenticated"
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Todos podem ler versoes" ON "public"."versoes"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Todos veem versoes" ON "public"."versoes"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "Acesso público para FOTOS-ANUNCIOS" ON "storage"."objects"
  FOR SELECT
  TO PUBLIC
  USING ((bucket_id = 'FOTOS-ANUNCIOS'::text));

CREATE POLICY "Acesso público para fotos-perfil" ON "storage"."objects"
  FOR SELECT
  TO PUBLIC
  USING ((bucket_id = 'fotos-perfil'::text));

CREATE POLICY "Leitura publica fotos anuncio" ON "storage"."objects"
  FOR SELECT
  TO PUBLIC
  USING ((bucket_id = 'FOTOS-ANUNCIOS'::text));

CREATE POLICY "Upload para usuários autenticados" ON "storage"."objects"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuarios autenticados atualizam fotos anuncio" ON "storage"."objects"
  FOR UPDATE
  TO "authenticated"
  USING ((bucket_id = 'FOTOS-ANUNCIOS'::text))
  WITH CHECK ((bucket_id = 'FOTOS-ANUNCIOS'::text));

CREATE POLICY "Usuarios autenticados enviam fotos anuncio" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((bucket_id = 'FOTOS-ANUNCIOS'::text));

CREATE POLICY "Usuarios autenticados removem fotos anuncio" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING ((bucket_id = 'FOTOS-ANUNCIOS'::text));

CREATE POLICY "Usuários autenticados podem atualizar FOTOS-ANUNCIOS" ON "storage"."objects"
  FOR UPDATE
  TO PUBLIC
  USING (((bucket_id = 'FOTOS-ANUNCIOS'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem atualizar perfil" ON "storage"."objects"
  FOR UPDATE
  TO PUBLIC
  USING (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem atualizar" ON "storage"."objects"
  FOR UPDATE
  TO PUBLIC
  USING (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)))
  WITH CHECK (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem deletar FOTOS-ANUNCIOS" ON "storage"."objects"
  FOR DELETE
  TO PUBLIC
  USING (((bucket_id = 'FOTOS-ANUNCIOS'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem deletar perfil" ON "storage"."objects"
  FOR DELETE
  TO PUBLIC
  USING (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem deletar" ON "storage"."objects"
  FOR DELETE
  TO PUBLIC
  USING (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem upload FOTOS-ANUNCIOS" ON "storage"."objects"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((bucket_id = 'FOTOS-ANUNCIOS'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem upload perfil" ON "storage"."objects"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários autenticados podem upload" ON "storage"."objects"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários podem atualizar suas fotos" ON "storage"."objects"
  FOR UPDATE
  TO PUBLIC
  USING (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "Usuários podem deletar suas fotos" ON "storage"."objects"
  FOR DELETE
  TO PUBLIC
  USING (((bucket_id = 'fotos-perfil'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "allow authenticaded uploads cn6lji_0" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((bucket_id = 'FOTOS-ANUNCIOS'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "public select cn6lji_0" ON "storage"."objects"
  FOR SELECT
  TO "anon"
  USING (((bucket_id = 'FOTOS-ANUNCIOS'::text) AND true));

CREATE POLICY "fc_delete" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING ((bucket_id = 'FOTOS-COMUNIDADE'::text));

CREATE POLICY "fc_select" ON "storage"."objects"
  FOR SELECT
  TO PUBLIC
  USING ((bucket_id = 'FOTOS-COMUNIDADE'::text));

CREATE POLICY "fc_update" ON "storage"."objects"
  FOR UPDATE
  TO "authenticated"
  USING ((bucket_id = 'FOTOS-COMUNIDADE'::text));

CREATE POLICY "fc_upload" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((bucket_id = 'FOTOS-COMUNIDADE'::text));

CREATE POLICY "fg_delete" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING ((bucket_id = 'FOTOS-GARAGEM'::text));

CREATE POLICY "fg_select" ON "storage"."objects"
  FOR SELECT
  TO PUBLIC
  USING ((bucket_id = 'FOTOS-GARAGEM'::text));

CREATE POLICY "fg_update" ON "storage"."objects"
  FOR UPDATE
  TO "authenticated"
  USING ((bucket_id = 'FOTOS-GARAGEM'::text));

CREATE POLICY "fg_upload" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((bucket_id = 'FOTOS-GARAGEM'::text));

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."mensagens";

COMMENT ON COLUMN "public"."anuncios"."horas_motor" IS 'Horas de uso do motor. Preenchido só quando tipo_veiculo = ''embarcacao''; nesse caso quilometragem fica NULL.';

COMMENT ON COLUMN "public"."anuncios"."quilometragem" IS 'Km rodados. Usado para carro, caminhao, moto, utilitario, maquina_agricola. NULL quando tipo_veiculo = ''embarcacao''.';

REVOKE ALL ON FUNCTION "public"."admin_atualizar_usuario"(text, boolean, boolean, numeric, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."admin_atualizar_usuario"(text, boolean, boolean, numeric, integer) TO "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."atualizar_contador_seguidores"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."atualizar_conversa"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."checar_cooldown_anuncio"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."criar_config_usuario"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."criar_tabela_carrinho"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."decrementar_curtidas"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."decrementar_curtidas_anuncio"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."decrementar_curtidas_post"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_anuncios_marketplace"(uuid) TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."incrementar_curtidas"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."incrementar_curtidas_anuncio"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."incrementar_curtidas_post"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."is_admin"() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."is_admin"() TO "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."limpar_dependencias_antes_excluir_anuncio"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

REVOKE ALL ON FUNCTION "public"."promover_moderador"(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."promover_moderador"(text) TO "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."proteger_campos_sensiveis_usuarios"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."proteger_conteudo_mensagens"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."proteger_status_anuncios"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."update_updated_at_column"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."verificar_cooldown_anuncio"() TO PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."anuncios" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."anuncios_opcionais" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."avaliacoes" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."carrinho_itens" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."comunidade_comentarios" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."comunidade_curtidas" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."comunidade_posts" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."comunidade_posts_fotos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."config_usuario" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."conversas" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."curtidas_anuncio" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."curtidas_post" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."denuncias" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."encontros" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."encontros_confirmados" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."favoritos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."fotos_anuncio" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."garagem_fotos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."garagem_gastos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."garagem_lembretes" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."garagem_manutencoes" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."garagem_veiculos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."marcas" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."mensagens" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modelos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."opcionais" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."posts_usuario" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."projetos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."projetos_atualizacoes" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."projetos_atualizacoes_fotos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."projetos_comentarios" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."projetos_curtidas" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."propostas" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."seguidores" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."usuarios" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."usuarios_banidos" TO "anon", "authenticated", "postgres", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."versoes" TO "anon", "authenticated", "postgres", "service_role";

GRANT USAGE ON TYPE "public"."status_anuncio" TO "postgres";

GRANT USAGE ON TYPE "public"."status_proposta" TO "postgres";

GRANT USAGE ON TYPE "public"."tipo_cambio" TO "postgres";

GRANT USAGE ON TYPE "public"."tipo_combustivel" TO "postgres";

