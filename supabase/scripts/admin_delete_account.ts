// ADMIN: hapus akun berdasarkan email, untuk permintaan hapus lewat email
// (kebijakan privasi, "nggak bisa buka app-nya lagi?"). Langkahnya sama dengan
// Edge Function delete-account: semua foto lewat Storage API, lalu user auth
// (data DB ikut terhapus lewat FK cascade, circle kosong ikut terhapus).
//
// Pakai (lokal atau produksi; service role key JANGAN disimpan di repo):
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=... \
//     deno run -A supabase/scripts/admin_delete_account.ts orang@contoh.com         # cek saja
//   ... admin_delete_account.ts orang@contoh.com --yes                               # hapus
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const email = Deno.args.find((a) => !a.startsWith("--"))?.trim().toLowerCase();
const confirmed = Deno.args.includes("--yes");

if (!serviceKey || !email) {
  console.error(
    "pakai: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... admin_delete_account.ts email [--yes]",
  );
  Deno.exit(1);
}

const admin = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

let userId: string | undefined;
for (let page = 1; !userId && page < 100; page++) {
  const { data, error } = await admin.auth.admin.listUsers({
    page,
    perPage: 200,
  });
  if (error) throw error;
  userId = data.users.find((u) => u.email?.toLowerCase() === email)?.id;
  if (data.users.length < 200) break;
}
if (!userId) {
  console.error(`tidak ada akun dengan email ${email} di ${url}.`);
  Deno.exit(1);
}

const { data: photos, error: listError } = await admin.rpc(
  "account_photo_paths",
  { p_user_id: userId },
);
if (listError) throw listError;
const paths = (photos as string[] | null) ?? [];
console.log(`${email} (${userId}) di ${url}: ${paths.length} foto.`);

if (!confirmed) {
  console.log("belum dihapus. jalankan ulang dengan --yes untuk menghapus.");
  Deno.exit(0);
}

for (let i = 0; i < paths.length; i += 100) {
  const { error } = await admin.storage.from("catch-photos").remove(
    paths.slice(i, i + 100),
  );
  if (error) throw error;
}
const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
if (deleteError) throw deleteError;
console.log("akun & semua datanya sudah dihapus.");
