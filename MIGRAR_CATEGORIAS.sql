-- ═══════════════════════════════════════════════════════════════════
-- RODAR AGORA NO SUPABASE → SQL Editor
-- Corrige colunas, categorias e seta admin
-- ═══════════════════════════════════════════════════════════════════

-- 1. COLUNAS QUE FALTAM (seguro rodar mesmo que já existam)
ALTER TABLE public.anuncios ADD COLUMN IF NOT EXISTS modelo_texto    TEXT;
ALTER TABLE public.anuncios ADD COLUMN IF NOT EXISTS pausado         BOOLEAN DEFAULT FALSE;
ALTER TABLE public.anuncios ADD COLUMN IF NOT EXISTS latitude        DOUBLE PRECISION;
ALTER TABLE public.anuncios ADD COLUMN IF NOT EXISTS longitude       DOUBLE PRECISION;
ALTER TABLE public.anuncios ADD COLUMN IF NOT EXISTS cidade_display  TEXT;
ALTER TABLE public.anuncios ADD COLUMN IF NOT EXISTS tipo_veiculo    TEXT DEFAULT 'carro';
ALTER TABLE public.marcas   ADD COLUMN IF NOT EXISTS categoria       TEXT DEFAULT 'carro';
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS moderador       BOOLEAN DEFAULT FALSE;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS banido          BOOLEAN DEFAULT FALSE;
ALTER TABLE public.mensagens ADD COLUMN IF NOT EXISTS tipo          TEXT DEFAULT 'texto';

-- 2. CORRIGIR CATEGORIAS ANTIGAS → NOVAS
UPDATE public.marcas SET categoria = 'maquina_agricola'
  WHERE categoria IN ('trator','colheitadeira');

UPDATE public.marcas SET categoria = 'barco'
  WHERE categoria = 'embarcacao'
  AND nome NOT IN ('Sea-Doo','Kawasaki Jet Ski','Yamaha WaveRunner');

UPDATE public.marcas SET categoria = 'jetski'
  WHERE nome IN ('Sea-Doo','Kawasaki Jet Ski','Yamaha WaveRunner');

UPDATE public.anuncios SET tipo_veiculo = 'maquina_agricola'
  WHERE tipo_veiculo IN ('trator','colheitadeira');

UPDATE public.anuncios SET tipo_veiculo = 'barco'
  WHERE tipo_veiculo = 'embarcacao';

-- 3. SETAR VOCÊ COMO ADMIN
UPDATE public.usuarios
  SET moderador = true
  WHERE email = 'murilofrank157@gmail.com';

-- 4. VERIFICAÇÃO (aparece o resultado logo abaixo)
SELECT 'Admin OK' AS resultado, email, moderador
  FROM public.usuarios WHERE email = 'murilofrank157@gmail.com';

SELECT 'Categorias' AS resultado, categoria, COUNT(*) AS total
  FROM public.marcas
  GROUP BY categoria ORDER BY categoria;
