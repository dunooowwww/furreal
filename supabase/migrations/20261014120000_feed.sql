-- M4: feed circle — reaksi, komentar, dan RPC feed hari ini (PRD §5).

-- ---------------------------------------------------------------------------
-- Helper: user boleh melihat catch ini (miliknya, atau satu circle dengan pemilik).
-- ---------------------------------------------------------------------------
create function public.can_see_catch(p_catch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.catches c
    where c.id = p_catch_id
      and (c.user_id = auth.uid() or public.shares_circle(auth.uid(), c.user_id))
  );
$$;

revoke execute on function public.can_see_catch(uuid) from public, anon;
grant execute on function public.can_see_catch(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- reactions
-- ---------------------------------------------------------------------------
create table public.reactions (
  catch_id uuid not null references public.catches (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  type text not null check (type in ('like', 'laugh')),
  created_at timestamptz not null default now(),
  primary key (catch_id, user_id, type)
);

create index reactions_user_id_idx on public.reactions (user_id);

alter table public.reactions enable row level security;
revoke all on public.reactions from anon, authenticated;
grant select, delete on public.reactions to authenticated;
grant insert (catch_id, user_id, type) on public.reactions to authenticated;

create policy "reactions: baca kalau bisa melihat catch-nya"
  on public.reactions for select to authenticated
  using (public.can_see_catch(catch_id));

create policy "reactions: buat atas nama sendiri di catch yang terlihat"
  on public.reactions for insert to authenticated
  with check (user_id = auth.uid() and public.can_see_catch(catch_id));

create policy "reactions: hapus milik sendiri"
  on public.reactions for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- comments
-- ---------------------------------------------------------------------------
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  catch_id uuid not null references public.catches (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 300),
  created_at timestamptz not null default now()
);

create index comments_catch_id_idx on public.comments (catch_id, created_at);
create index comments_user_id_idx on public.comments (user_id);

alter table public.comments enable row level security;
revoke all on public.comments from anon, authenticated;
grant select, delete on public.comments to authenticated;
grant insert (id, catch_id, user_id, body) on public.comments to authenticated;

create policy "comments: baca kalau bisa melihat catch-nya"
  on public.comments for select to authenticated
  using (public.can_see_catch(catch_id));

create policy "comments: buat atas nama sendiri di catch yang terlihat"
  on public.comments for insert to authenticated
  with check (user_id = auth.uid() and public.can_see_catch(catch_id));

create policy "comments: hapus milik sendiri"
  on public.comments for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Feed circle hari ini (Asia/Jakarta), terbaru dulu. security invoker: RLS
-- catches/animals/profiles/reactions tetap berlaku untuk pemanggil.
-- ---------------------------------------------------------------------------
create function public.circle_feed(p_circle_id uuid)
returns table (
  catch_id uuid,
  user_id uuid,
  username text,
  display_name text,
  created_at timestamptz,
  is_late boolean,
  late_minutes int,
  animal_name text,
  animal_type text,
  encounter_count int,
  personality text,
  animal_photo_path text,
  selfie_photo_path text,
  like_count int,
  laugh_count int,
  comment_count int,
  liked_by_me boolean,
  laughed_by_me boolean
)
language sql
stable
set search_path = ''
as $$
  select
    c.id,
    c.user_id,
    p.username,
    p.display_name,
    c.created_at,
    c.is_late,
    case when c.is_late then
      greatest(0, floor(extract(epoch from (c.created_at - (d.sent_at + interval '1 hour'))) / 60))::int
    end,
    a.name,
    coalesce(a.animal_type, c.ai_type),
    coalesce(a.encounter_count, 1),
    coalesce(c.personality, c.ai_personality),
    c.animal_photo_path,
    c.selfie_photo_path,
    (select count(*)::int from public.reactions r where r.catch_id = c.id and r.type = 'like'),
    (select count(*)::int from public.reactions r where r.catch_id = c.id and r.type = 'laugh'),
    (select count(*)::int from public.comments m where m.catch_id = c.id),
    exists (select 1 from public.reactions r
            where r.catch_id = c.id and r.type = 'like' and r.user_id = auth.uid()),
    exists (select 1 from public.reactions r
            where r.catch_id = c.id and r.type = 'laugh' and r.user_id = auth.uid())
  from public.circle_members cm
  join public.catches c on c.user_id = cm.user_id
  left join public.profiles p on p.id = c.user_id
  left join public.animals a on a.id = c.animal_id
  left join public.daily_drops d on d.drop_date = c.catch_date
  where cm.circle_id = p_circle_id
    and c.catch_date = public.jakarta_today()
  order by c.created_at desc;
$$;

revoke execute on function public.circle_feed(uuid) from public, anon;
grant execute on function public.circle_feed(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Komentar sebuah catch + nama penulisnya. security definer supaya nama
-- penulis terbaca walau penulis beda circle dengan pembaca (komentarnya
-- sendiri sudah terlihat oleh pembaca lewat aturan catch).
-- ---------------------------------------------------------------------------
create function public.catch_comments(p_catch_id uuid)
returns table (
  id uuid,
  user_id uuid,
  username text,
  display_name text,
  body text,
  created_at timestamptz,
  is_mine boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.user_id, p.username, p.display_name, m.body, m.created_at,
         m.user_id = auth.uid()
  from public.comments m
  join public.profiles p on p.id = m.user_id
  where m.catch_id = p_catch_id
    and public.can_see_catch(p_catch_id)
  order by m.created_at;
$$;

revoke execute on function public.catch_comments(uuid) from public, anon;
grant execute on function public.catch_comments(uuid) to authenticated;
