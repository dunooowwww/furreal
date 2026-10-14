// Helper DEBUG daily drop (M6): turunkan drop hari ini sekarang, atau kunci lagi,
// supaya kamera/notifikasi bisa dites tanpa menunggu jam acak 10:00–20:00.
//
// Pakai (Supabase lokal + `npx supabase functions serve --env-file supabase/.env`):
//   SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_drop.ts          # turun sekarang
//   SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_drop.ts --lock   # kunci sampai 23:59 WIB
//   SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_drop.ts --status
//
// "turun sekarang" memakai jalur asli: dispatch_daily_drop() → pg_net →
// send-daily-drop → claim_daily_drop() + FCM (kalau FCM_SERVICE_ACCOUNT_JSON diisi).
import { admin, check, jakartaDate } from "./_dev.ts";

const today = jakartaDate();
const mode = Deno.args.includes("--lock")
  ? "lock"
  : Deno.args.includes("--status")
  ? "status"
  : "now";

async function status() {
  const row = check(
    "baca daily_drops",
    await admin.from("daily_drops").select("scheduled_at, sent_at").eq(
      "drop_date",
      today,
    ).maybeSingle(),
  );
  const fmt = (v: unknown) =>
    typeof v === "string"
      ? new Date(v).toLocaleString("id-ID", { timeZone: "Asia/Jakarta" })
      : "-";
  console.log(
    `drop ${today}: jadwal ${fmt(row?.scheduled_at)}, turun ${
      fmt(row?.sent_at)
    }`,
  );
  return row;
}

if (mode === "status") {
  await status();
  Deno.exit(0);
}

if (mode === "lock") {
  // Jam 23:59 WIB hari ini: cron tidak akan menurunkannya sebelum itu.
  const lockUntil = `${today}T23:59:00+07:00`;
  check(
    "kunci drop",
    await admin.from("daily_drops").upsert({
      drop_date: today,
      scheduled_at: lockUntil,
      sent_at: null,
    }),
  );
  console.log("drop hari ini dikunci (kamera terkunci sampai 23:59 WIB).");
  console.log(
    "catch hari ini yang sudah ada tidak dihapus; pakai tombol debug di beranda.",
  );
  await status();
  Deno.exit(0);
}

check(
  "jadwalkan drop sekarang",
  await admin.from("daily_drops").upsert({
    drop_date: today,
    scheduled_at: new Date().toISOString(),
    sent_at: null,
  }),
);
const requestId = check(
  "dispatch_daily_drop",
  await admin.rpc("dispatch_daily_drop"),
);
if (requestId == null) {
  console.error(
    "dispatch tidak memanggil apa pun: Vault daily_drop_url/daily_drop_secret kosong? jalankan `npx supabase db reset`.",
  );
  Deno.exit(1);
}

console.log("drop dijadwalkan sekarang, menunggu send-daily-drop…");
for (let i = 0; i < 20; i++) {
  await new Promise((r) => setTimeout(r, 1000));
  const row = check(
    "baca daily_drops",
    await admin.from("daily_drops").select("sent_at").eq("drop_date", today)
      .maybeSingle(),
  );
  if (row?.sent_at) {
    await status();
    console.log(
      "drop turun! buka/refresh beranda di app. log FCM ada di terminal functions serve.",
    );
    Deno.exit(0);
  }
}
console.error(
  "send-daily-drop belum mengklaim drop. pastikan `npx supabase functions serve --env-file supabase/.env` jalan dan DAILY_DROP_SECRET sama dengan Vault.",
);
Deno.exit(1);
