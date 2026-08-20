alter table public.pets add column photo_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pet-photos', 'pet-photos', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "pet_photos_owner_all" on storage.objects
  for all to authenticated
  using (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pet_photos_public_read" on storage.objects
  for select using (bucket_id = 'pet-photos');
