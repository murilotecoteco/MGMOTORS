-- Fotos de conversas ficam separadas das fotos públicas dos anúncios.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'FOTOS-MENSAGENS',
  'FOTOS-MENSAGENS',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = 5242880,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS fotos_mensagens_select_participante ON storage.objects;
CREATE POLICY fotos_mensagens_select_participante ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'FOTOS-MENSAGENS'
    AND (storage.foldername(name))[1] = 'mensagens'
    AND (
      (storage.foldername(name))[2] = auth.uid()::text
      OR EXISTS (
        SELECT 1
        FROM public.mensagens AS m
        WHERE m.tipo = 'foto'
          AND m.conteudo LIKE '%' || name
          AND (m.remetente_id = auth.uid() OR m.destinatario_id = auth.uid())
          AND (
            m.remetente_id::text = (storage.foldername(name))[2]
            OR m.destinatario_id::text = (storage.foldername(name))[2]
          )
      )
    )
  );

DROP POLICY IF EXISTS fotos_mensagens_insert_dono ON storage.objects;
CREATE POLICY fotos_mensagens_insert_dono ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'FOTOS-MENSAGENS'
    AND (storage.foldername(name))[1] = 'mensagens'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS fotos_mensagens_update_dono ON storage.objects;
CREATE POLICY fotos_mensagens_update_dono ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'FOTOS-MENSAGENS'
    AND (storage.foldername(name))[1] = 'mensagens'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'FOTOS-MENSAGENS'
    AND (storage.foldername(name))[1] = 'mensagens'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS fotos_mensagens_delete_dono ON storage.objects;
CREATE POLICY fotos_mensagens_delete_dono ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'FOTOS-MENSAGENS'
    AND (storage.foldername(name))[1] = 'mensagens'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );
