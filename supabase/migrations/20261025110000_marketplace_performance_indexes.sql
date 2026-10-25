-- Índices para os caminhos públicos mais frequentes.
-- Não alteram dados nem policies; podem ser aplicados sem indisponibilidade.

CREATE INDEX IF NOT EXISTS idx_anuncios_marketplace_ativos_recentes
  ON public.anuncios (criado_em DESC)
  WHERE status = 'ativo' AND COALESCE(pausado, false) = false;

CREATE INDEX IF NOT EXISTS idx_anuncios_marketplace_tipo_estado
  ON public.anuncios (tipo_veiculo, estado, criado_em DESC)
  WHERE status = 'ativo' AND COALESCE(pausado, false) = false;

CREATE INDEX IF NOT EXISTS idx_anuncios_marketplace_preco
  ON public.anuncios (preco)
  WHERE status = 'ativo' AND COALESCE(pausado, false) = false;

CREATE INDEX IF NOT EXISTS idx_fotos_anuncio_principal
  ON public.fotos_anuncio (anuncio_id, ordem ASC);

CREATE INDEX IF NOT EXISTS idx_curtidas_anuncio_usuario_anuncio
  ON public.curtidas_anuncio (usuario_id, anuncio_id);
