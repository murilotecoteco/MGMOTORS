-- Compatibilidade: uma foto criada durante a transição pode ter o caminho
-- privado salvo em conteudo antes de tipo='foto' ser persistido corretamente.
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
        WHERE (m.tipo = 'foto' OR m.conteudo LIKE 'mensagens/%')
          AND m.conteudo LIKE '%' || name
          AND (m.remetente_id = auth.uid() OR m.destinatario_id = auth.uid())
          AND (
            m.remetente_id::text = (storage.foldername(name))[2]
            OR m.destinatario_id::text = (storage.foldername(name))[2]
          )
      )
    )
  );
