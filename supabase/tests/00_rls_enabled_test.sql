-- Penjaga: setiap tabel di schema public WAJIB mengaktifkan RLS (PRD §5).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(1);

select is_empty(
  $$
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity
  $$,
  'semua tabel di schema public mengaktifkan RLS'
);

select * from finish();
rollback;
