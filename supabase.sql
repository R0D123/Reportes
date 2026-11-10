-- Ejecutar una vez en Supabase > SQL Editor.
-- Crear ANTES el bucket PRIVADO 'dts-excels' en Storage.
-- Cada usuario ve únicamente sus periodos y sus Excel originales.

create extension if not exists pgcrypto;

create table if not exists public.dts_imports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  period text not null,
  rows jsonb not null default '[]'::jsonb,
  source_filename text not null,
  storage_path text not null,
  updated_at timestamptz not null default now(),
  constraint dts_imports_rows_array check (jsonb_typeof(rows) = 'array'),
  constraint dts_imports_unique_period unique (user_id, period)
);

alter table public.dts_imports enable row level security;
revoke all on public.dts_imports from anon;
grant select, insert, update, delete on public.dts_imports to authenticated;

drop policy if exists "dts_select_own" on public.dts_imports;
create policy "dts_select_own" on public.dts_imports
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "dts_insert_own" on public.dts_imports;
create policy "dts_insert_own" on public.dts_imports
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "dts_update_own" on public.dts_imports;
create policy "dts_update_own" on public.dts_imports
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "dts_delete_own" on public.dts_imports;
create policy "dts_delete_own" on public.dts_imports
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Los objetos están en: <uuid-usuario>/<uuid-archivo>.xlsx|xls|csv
-- Bucket privado: cualquier operación de lectura requiere autenticación y SELECT.
drop policy if exists "dts_storage_select_own" on storage.objects;
create policy "dts_storage_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'dts-excels'
    and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "dts_storage_insert_own" on storage.objects;
create policy "dts_storage_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'dts-excels'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and lower(storage.extension(name)) in ('xlsx', 'xls', 'csv'));

drop policy if exists "dts_storage_delete_own" on storage.objects;
create policy "dts_storage_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'dts-excels'
    and (storage.foldername(name))[1] = (select auth.uid()::text));
