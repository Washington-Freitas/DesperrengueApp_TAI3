-- ============================================================================
-- DESPERRENGUE — Migration 3/3: Storage do KYC
--
-- Antes: bucket `kyc_documentos` PÚBLICO (URL aberta para RG/selfie) e policy
-- que permitia upload de qualquer usuário em qualquer caminho.
-- Agora: bucket PRIVADO `kyc-documents`, cada usuário só escreve/lê dentro da
-- própria pasta `<auth.uid()>/...`; admins leem tudo; acesso via signed URL.
-- ============================================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('kyc-documents', 'kyc-documents', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "kyc_documents_insert_own_folder" on storage.objects;
drop policy if exists "kyc_documents_select_own_or_admin" on storage.objects;

create policy "kyc_documents_insert_own_folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'kyc-documents'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "kyc_documents_select_own_or_admin" on storage.objects
  for select to authenticated
  using (bucket_id = 'kyc-documents'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- Bucket legado: deixa de ser público e perde a policy permissiva.
-- (Os arquivos de teste permanecem; apague-os pelo dashboard quando desejar.)
drop policy if exists "Permitir upload autenticado" on storage.objects;
update storage.buckets set public = false where id = 'kyc_documentos';

commit;
