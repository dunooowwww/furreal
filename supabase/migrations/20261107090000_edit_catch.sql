-- M13: edit & hapus catch sendiri.
--
-- - Caption bisa diubah lewat edit_catch (nama hewan lewat update animals,
--   hak kolom name sudah ada sejak M2).
-- - Hapus catch (hari ini, dari app) sudah boleh lewat RLS sejak M2; sekarang
--   streak ikut dihitung ulang supaya tidak tersisa +1 dari catch yang dihapus.

create function public.edit_catch(p_catch_id uuid, p_caption text)
returns public.catches
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_catch public.catches;
begin
  if auth.uid() is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  update public.catches
     set caption = left(nullif(btrim(p_caption), ''), 150)
   where id = p_catch_id and user_id = auth.uid()
  returning * into v_catch;
  if not found then
    raise exception 'catch bukan milikmu' using errcode = 'P0002';
  end if;
  return v_catch;
end;
$$;

revoke execute on function public.edit_catch(uuid, text) from public, anon;
grant execute on function public.edit_catch(uuid, text) to authenticated;

-- Streak dihitung ulang dari sisa riwayat setelah catch dihapus. Dilewati
-- untuk hapus berantai (hapus akun): profil & streak-nya ikut terhapus.
create function public.recompute_streak_after_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.recompute_streak(old.user_id);
  return null;
end;
$$;

revoke execute on function public.recompute_streak_after_delete() from public, anon, authenticated;

create trigger catches_recompute_streak_after_delete
  after delete on public.catches
  for each row
  when (pg_trigger_depth() < 1)
  execute function public.recompute_streak_after_delete();
