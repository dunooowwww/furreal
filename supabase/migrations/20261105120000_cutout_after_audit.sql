-- Gabungan audit (27 Okt) + M11: potongan hewan (cutout.png) di-upload SETELAH
-- posting dan boleh di-upload ulang (retry, backfill). Kunci foto yang sudah
-- diposting hanya untuk foto catch aslinya: animal.jpg dan selfie.jpg.
create or replace function public.is_posted_catch_photo(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(animal|selfie)\.jpg$' then
    return false;
  end if;
  return exists (
    select 1 from public.catches c
    where c.id = split_part(p_name, '/', 2)::uuid
      and c.user_id = split_part(p_name, '/', 1)::uuid
  );
end;
$$;
