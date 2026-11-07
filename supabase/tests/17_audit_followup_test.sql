-- Tindak lanjut audit: satu create_catch saja, fungsi trigger tidak bisa
-- dipanggil user.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(3);

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_catch'),
  1,
  'hanya ada satu create_catch (9 argumen, dengan caption)'
);

select is_empty(
  $$select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and has_function_privilege('anon', p.oid, 'execute')
      and p.proname <> 'resolve_login'$$,
  'anon hanya bisa memanggil resolve_login di antara fungsi security definer'
);

select is_empty(
  $$select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
      and has_function_privilege('authenticated', p.oid, 'execute')$$,
  'fungsi trigger tidak bisa dipanggil user'
);

select * from finish();
rollback;
