// Helper DEBUG: hapus catch hari ini milik akunmu supaya bisa catch lagi.
// Menggantikan tombol "hapus catch hari ini (debug)" di app: sejak audit
// 27 Okt user tidak bisa menghapus catch lewat API (bisa dipakai buat
// mengakali satu catch per hari dan spam notifikasi "teman udah catch").
//
// Pakai (Supabase lokal harus jalan):
//   SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/reset_dev_today.ts emailkamu@contoh.com
//
// - Foto catch dihapus lewat Storage API, lalu baris catch-nya.
// - Hewannya ikut dihapus kalau dibuat oleh catch ini (tanpa catch lain);
//   hewan "ketemu lagi" tetap, encounter_count-nya turun lewat trigger.
// - Streak dihitung ulang dari riwayat (recompute_streak).
import { admin, check, findUserIdByEmail, jakartaDate, must } from "./_dev.ts";

const email = Deno.args.find((a) => !a.startsWith("--"))?.trim().toLowerCase();
if (!email) {
  console.error("pakai: reset_dev_today.ts emailkamu@contoh.com");
  Deno.exit(1);
}

const userId = await findUserIdByEmail(email);
if (!userId) {
  console.error(`akun ${email} belum ada.`);
  Deno.exit(1);
}

const today = jakartaDate();
const rows = must(
  "catch hari ini",
  await admin
    .from("catches")
    .select("id, animal_id, animal_photo_path, selfie_photo_path")
    .eq("user_id", userId)
    .eq("catch_date", today),
);
const caught = rows[0];
if (!caught) {
  console.log(
    `${email} belum catch hari ini (${today}). tidak ada yang dihapus.`,
  );
  Deno.exit(0);
}

check(
  "hapus foto",
  await admin.storage
    .from("catch-photos")
    .remove([caught.animal_photo_path, caught.selfie_photo_path]),
);
check(
  "hapus catch",
  await admin.from("catches").delete().eq("id", caught.id),
);

if (caught.animal_id) {
  const others = must(
    "catch lain hewan ini",
    await admin
      .from("catches")
      .select("id")
      .eq("animal_id", caught.animal_id)
      .limit(1),
  );
  if (others.length === 0) {
    check(
      "hapus hewan",
      await admin.from("animals").delete().eq("id", caught.animal_id),
    );
  }
}

check(
  "hitung ulang streak",
  await admin.rpc("recompute_streak", { p_user_id: userId }),
);

console.log(
  `catch hari ini (${today}) milik ${email} dihapus. boleh catch lagi.`,
);
