// Helper DEBUG streak (M5): buat catch untuk akunmu di hari-hari lalu, supaya
// streak & "ketemu lagi" bisa dites tanpa menunggu berhari-hari.
//
// Pakai (Supabase lokal harus jalan, akun sudah pernah login di app):
//   SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_streak.ts emailkamu@contoh.com --days 3
//   ... --days 4 --gap    # bolongkan 2 hari lalu → streak putus
//
// - Catch dibuat dari N hari lalu sampai kemarin (hari yang sudah ada catch dilewati).
// - Catch pertama = hewan baru "Debu"; berikutnya "ketemu lagi" Debu, kecuali satu
//   hewan baru "Kiko" supaya koleksi berisi lebih dari satu hewan.
// - Setelah itu streak dihitung ulang dari riwayat (recompute_streak).
import {
  admin,
  check,
  findUserIdByEmail,
  jakartaDate,
  must,
  type SamplePhoto,
  uploadSamplePhotos,
} from "./_dev.ts";

const args = Deno.args;
const email = args.find((a) => !a.startsWith("--"))?.trim().toLowerCase();
const daysArg = args[args.indexOf("--days") + 1];
const days = args.includes("--days") ? Number(daysArg) : 3;
const gap = args.includes("--gap");

if (!email) {
  console.error(
    "pakai: seed_dev_streak.ts emailkamu@contoh.com [--days N] [--gap]",
  );
  Deno.exit(1);
}
if (!Number.isInteger(days) || days < 1 || days > 60) {
  console.error("--days harus angka 1 sampai 60.");
  Deno.exit(1);
}

const userId = await findUserIdByEmail(email);
if (!userId) {
  console.error(
    `akun ${email} belum ada. login dulu di app (OTP), lalu jalankan ulang.`,
  );
  Deno.exit(1);
}

const existing = new Set(
  must(
    "catch yang sudah ada",
    await admin.from("catches").select("catch_date").eq("user_id", userId),
  ).map((c) => c.catch_date as string),
);

let debuId: string | undefined;
let created = 0;
for (let daysAgo = days; daysAgo >= 1; daysAgo--) {
  if (gap && daysAgo === 2) continue;
  const date = jakartaDate(daysAgo);
  if (existing.has(date)) {
    console.log(`${date}: sudah ada catch, dilewati.`);
    continue;
  }

  // satu hari di tengah jadi hewan baru "Kiko"; sisanya Debu (baru, lalu ketemu lagi)
  const isKiko = days >= 3 && daysAgo === Math.ceil(days / 2) && !!debuId;
  let animalId = isKiko ? undefined : debuId;
  const photo: SamplePhoto = isKiko ? "kiko" : "mochi";
  if (!animalId) {
    const animal = must(
      "hewan baru",
      await admin.from("animals").insert({
        owner_id: userId,
        name: isKiko ? "Kiko" : "Debu",
        kind: isKiko ? "pet" : "wild",
        animal_type: isKiko ? "burung" : "kucing",
      }).select("id").single(),
    );
    animalId = animal.id as string;
    if (!isKiko) debuId = animalId;
  }

  const catchId = crypto.randomUUID();
  const paths = await uploadSamplePhotos(userId, catchId, photo);
  check(
    `catch ${date}`,
    await admin.from("catches").insert({
      id: catchId,
      user_id: userId,
      animal_id: animalId,
      animal_photo_path: paths.animal,
      selfie_photo_path: paths.selfie,
      ai_type: isKiko ? "burung" : "kucing",
      personality: isKiko
        ? "nyanyi jam 5 pagi tanpa diminta."
        : `catch debug ${daysAgo} hari lalu. tetap setia nongkrong di tempat yang sama.`,
      location_hidden: true,
      is_late: false,
      catch_date: date,
      // tengah hari WIB di tanggal itu
      created_at: new Date(`${date}T05:00:00Z`).toISOString(),
    }),
  );
  console.log(
    `${date}: catch ${
      isKiko
        ? "Kiko (hewan baru)"
        : animalId === debuId && created > 0
        ? "Debu (ketemu lagi)"
        : "Debu (hewan baru)"
    }`,
  );
  created++;
}

const streak = must(
  "hitung ulang streak",
  await admin.rpc("recompute_streak", { p_user_id: userId }),
);
console.log(
  `siap! ${created} catch dibuat. streak sekarang ${streak.current} (terpanjang ${streak.longest}), catch terakhir ${streak.last_catch_date}.`,
);
if (!existing.has(jakartaDate(0))) {
  console.log("catch hari ini di app → streak bertambah 1 lewat trigger.");
}
