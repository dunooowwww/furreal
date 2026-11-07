-- M17: reaksi baru (😻 cute, 🔥 fire, 🥺 aww) + kartu favorit (pajangan).
--
-- - reactions.type: like, laugh, cute, fire, aww.
-- - circle_feed v5: + reaction_counts (jsonb per jenis) & my_reactions.
--   Kolom lama (like_count, dst.) tetap supaya APK lama tidak rusak.
-- - animals.pinned_at: maksimal 3 kartu dipajang di atas koleksi
--   (set_animal_pinned, FR007 kalau sudah 3). my_collection v4 + pinned_at.

alter table public.reactions drop constraint reactions_type_check;
alter table public.reactions
  add constraint reactions_type_check
  check (type in ('like', 'laugh', 'cute', 'fire', 'aww'));

-- ---------------------------------------------------------------------------
-- Feed v5
-- ---------------------------------------------------------------------------
drop function public.circle_feed(uuid);

create function public.circle_feed(p_circle_id uuid)
returns table (
  catch_id uuid,
  user_id uuid,
  username text,
  display_name text,
  avatar_path text,
  created_at timestamptz,
  is_late boolean,
  late_minutes int,
  timing text,
  locked boolean,
  animal_name text,
  animal_type text,
  encounter_count int,
  caption text,
  animal_photo_path text,
  selfie_photo_path text,
  like_count int,
  laugh_count int,
  comment_count int,
  liked_by_me boolean,
  laughed_by_me boolean,
  reaction_counts jsonb,
  my_reactions text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  with feed as (
    select c.*, not public.can_view_catch_content(c.user_id, c.catch_date) as locked
    from public.circle_members cm
    join public.catches c on c.user_id = cm.user_id
    where cm.circle_id = p_circle_id
      and c.catch_date = public.jakarta_today()
      and public.is_circle_member(p_circle_id)
  )
  select
    f.id,
    f.user_id,
    p.username,
    p.display_name,
    p.avatar_path,
    f.created_at,
    f.is_late,
    case when f.is_late then
      greatest(0, floor(extract(epoch from (f.created_at - (d.sent_at + interval '1 hour'))) / 60))::int
    end,
    f.timing,
    f.locked,
    case when not f.locked then a.name end,
    case when not f.locked then coalesce(a.animal_type, f.ai_type) end,
    case when not f.locked then coalesce(a.encounter_count, 1) end,
    case when not f.locked then f.caption end,
    case when not f.locked then f.animal_photo_path end,
    case when not f.locked then f.selfie_photo_path end,
    case when f.locked then 0 else
      (select count(*)::int from public.reactions r where r.catch_id = f.id and r.type = 'like') end,
    case when f.locked then 0 else
      (select count(*)::int from public.reactions r where r.catch_id = f.id and r.type = 'laugh') end,
    case when f.locked then 0 else
      (select count(*)::int from public.comments m where m.catch_id = f.id) end,
    exists (select 1 from public.reactions r
            where r.catch_id = f.id and r.type = 'like' and r.user_id = auth.uid()),
    exists (select 1 from public.reactions r
            where r.catch_id = f.id and r.type = 'laugh' and r.user_id = auth.uid()),
    case when f.locked then '{}'::jsonb else
      coalesce((select jsonb_object_agg(x.type, x.n)
                from (select r.type, count(*)::int as n from public.reactions r
                      where r.catch_id = f.id group by r.type) x), '{}'::jsonb) end,
    coalesce((select array_agg(r.type order by r.type) from public.reactions r
              where r.catch_id = f.id and r.user_id = auth.uid()), '{}')
  from feed f
  left join public.profiles p on p.id = f.user_id
  left join public.animals a on a.id = f.animal_id
  left join public.daily_drops d on d.drop_date = f.catch_date
  order by f.created_at desc;
$$;

revoke execute on function public.circle_feed(uuid) from public, anon;
grant execute on function public.circle_feed(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Kartu favorit
-- ---------------------------------------------------------------------------
alter table public.animals add column pinned_at timestamptz;

create function public.set_animal_pinned(p_animal_id uuid, p_pinned boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.animals
    where id = p_animal_id and owner_id = v_uid and removed_at is null
  ) then
    raise exception 'hewan bukan milikmu' using errcode = 'P0002';
  end if;

  if not coalesce(p_pinned, false) then
    update public.animals set pinned_at = null where id = p_animal_id;
    return;
  end if;

  -- Kunci baris hewan milik user supaya dua pin bersamaan tidak lolos batas.
  perform 1 from public.animals where owner_id = v_uid for update;
  if (
    select count(*) from public.animals
    where owner_id = v_uid and pinned_at is not null and removed_at is null
      and id <> p_animal_id
  ) >= 3 then
    raise exception 'maksimal 3 kartu favorit' using errcode = 'FR007';
  end if;
  update public.animals
     set pinned_at = coalesce(pinned_at, now())
   where id = p_animal_id;
end;
$$;

revoke execute on function public.set_animal_pinned(uuid, boolean) from public, anon;
grant execute on function public.set_animal_pinned(uuid, boolean) to authenticated;

-- Hapus dari koleksi = lepas juga dari pajangan.
create or replace function public.remove_animal(p_animal_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  update public.animals
     set removed_at = now(),
         pinned_at = null
   where id = p_animal_id
     and owner_id = auth.uid()
     and removed_at is null;
  if not found then
    raise exception 'hewan bukan milikmu' using errcode = 'P0002';
  end if;
end;
$$;

-- Koleksi v4: + pinned_at.
drop function public.my_collection();

create function public.my_collection()
returns table (
  animal_id uuid,
  name text,
  kind text,
  animal_type text,
  encounter_count int,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  last_animal_photo_path text,
  last_personality text,
  last_catch_id uuid,
  last_cutout_path text,
  last_cutout_attempted boolean,
  last_catch_date date,
  last_area_label text,
  pinned_at timestamptz
)
language sql
stable
set search_path = ''
as $$
  select a.id, a.name, a.kind, a.animal_type, a.encounter_count,
         a.first_seen_at, a.last_seen_at,
         lc.animal_photo_path, coalesce(a.personality, lc.personality),
         lc.id, lc.cutout_path, coalesce(lc.cutout_attempted, false),
         lc.catch_date, lc.area_label, a.pinned_at
  from public.animals a
  left join lateral (
    select c.id, c.animal_photo_path, c.cutout_path, c.cutout_attempted,
           c.catch_date, c.area_label,
           coalesce(c.personality, c.ai_personality) as personality
    from public.catches c
    where c.animal_id = a.id
    order by c.created_at desc
    limit 1
  ) lc on true
  where a.owner_id = auth.uid()
    and a.removed_at is null
  order by a.last_seen_at desc, a.name;
$$;

revoke execute on function public.my_collection() from public, anon;
grant execute on function public.my_collection() to authenticated;
