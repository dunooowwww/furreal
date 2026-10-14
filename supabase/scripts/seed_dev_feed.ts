// Seed DEVELOPMENT untuk feed (M4): 4 user contoh, 1 circle, catch hari ini
// lengkap dengan foto, reaksi, dan komentar. Akunmu ikut dimasukkan ke circle.
//
// Pakai (Supabase lokal harus jalan):
//   npx supabase status -o env        # ambil SERVICE_ROLE_KEY
//   SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_feed.ts emailkamu@contoh.com
//
// Aman dijalankan ulang (mis. tiap hari): catch hari ini milik user contoh
// diganti yang baru. Skrip menolak jalan ke Supabase non-lokal.
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const myEmail = Deno.args[0]?.trim().toLowerCase();

if (!/^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?\/?$/.test(url)) {
  console.error(
    `menolak: ${url} bukan Supabase lokal. skrip ini khusus development.`,
  );
  Deno.exit(1);
}
if (!serviceKey) {
  console.error(
    "isi SUPABASE_SERVICE_ROLE_KEY (lihat `npx supabase status -o env`).",
  );
  Deno.exit(1);
}

const admin = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const CIRCLE = { name: "anak kos merpati", invite_code: "KSM234" };
const PHOTOS = new URL("./seed_photos/", import.meta.url);

type SeedUser = {
  key: string;
  email: string;
  username: string;
  display_name: string;
  catch?: {
    photo: string;
    minutesAgo: number;
    late: boolean;
    animal: {
      name: string;
      kind: "pet" | "wild";
      animal_type: string;
      encounter_count: number;
    };
    ai_confidence: number;
    personality: string;
  };
};

const USERS: SeedUser[] = [
  {
    key: "dinda",
    email: "dinda@furreal.test",
    username: "dinda",
    display_name: "dinda",
    catch: {
      photo: "mochi",
      minutesAgo: 2,
      late: false,
      animal: {
        name: "Mochi",
        kind: "pet",
        animal_type: "kucing",
        encounter_count: 12,
      },
      ai_confidence: 0.96,
      personality: "bos kamar 4b. nolak semua makanan kecuali yang mahal.",
    },
  },
  {
    key: "raka",
    email: "raka@furreal.test",
    username: "raka",
    display_name: "raka",
    catch: {
      photo: "pakkwek",
      minutesAgo: 18,
      late: true,
      animal: {
        name: "Pak Kwek",
        kind: "wild",
        animal_type: "bebek",
        encounter_count: 1,
      },
      ai_confidence: 0.88,
      personality: "patroli selokan tiap pagi. tidak menerima kritik.",
    },
  },
  {
    key: "bimo",
    email: "bimo@furreal.test",
    username: "bimo",
    display_name: "bimo",
    catch: {
      photo: "kiko",
      minutesAgo: 60,
      late: false,
      animal: {
        name: "Kiko",
        kind: "pet",
        animal_type: "burung",
        encounter_count: 5,
      },
      ai_confidence: 0.81,
      personality:
        "nyanyi jam 5 pagi tanpa diminta. fans-nya cuma dirinya sendiri.",
    },
  },
  // sasa belum catch hari ini (supaya "x dari y udah catch" terasa)
  {
    key: "sasa",
    email: "sasa@furreal.test",
    username: "sasa",
    display_name: "sasa",
  },
];

/** Ambil `data` dari hasil supabase-js, keluar dengan pesan kalau error. */
function must<T>(
  label: string,
  result: { data: T; error: unknown },
): NonNullable<T> {
  if (result.error || result.data == null) {
    console.error(`gagal ${label}:`, result.error ?? "data kosong");
    Deno.exit(1);
  }
  return result.data as NonNullable<T>;
}

/** Seperti must(), tapi `data` boleh null (mis. maybeSingle). */
function check<T>(label: string, result: { data: T; error: unknown }): T {
  if (result.error) {
    console.error(`gagal ${label}:`, result.error);
    Deno.exit(1);
  }
  return result.data;
}

/** Tanggal hari ini Asia/Jakarta (UTC+7), sama dengan public.jakarta_today(). */
function jakartaToday(): string {
  return new Date(Date.now() + 7 * 3600_000).toISOString().slice(0, 10);
}

async function findUserIdByEmail(email: string): Promise<string | undefined> {
  for (let page = 1; page < 50; page++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 200,
    });
    if (error) {
      console.error("gagal listUsers:", error);
      Deno.exit(1);
    }
    const found = data.users.find((user) =>
      user.email?.toLowerCase() === email
    );
    if (found) return found.id;
    if (data.users.length < 200) return undefined;
  }
}

async function ensureUser(u: SeedUser): Promise<string> {
  let id = await findUserIdByEmail(u.email);
  if (!id) {
    const { data, error } = await admin.auth.admin.createUser({
      email: u.email,
      email_confirm: true,
    });
    if (error || !data.user) {
      console.error(`gagal buat user ${u.email}:`, error);
      Deno.exit(1);
    }
    id = data.user.id;
  }
  check(
    `profil ${u.username}`,
    await admin.from("profiles").update({
      username: u.username,
      display_name: u.display_name,
    })
      .eq("id", id),
  );
  return id;
}

async function main() {
  const today = jakartaToday();
  const ids: Record<string, string> = {};
  for (const u of USERS) ids[u.key] = await ensureUser(u);

  // circle
  let circle = check(
    "cari circle",
    await admin.from("circles").select("id").eq(
      "invite_code",
      CIRCLE.invite_code,
    ).maybeSingle(),
  );
  if (!circle) {
    circle = must(
      "buat circle",
      await admin.from("circles").insert({ ...CIRCLE, created_by: ids.dinda })
        .select("id").single(),
    );
  }
  const circleId = circle.id as string;

  const memberIds = Object.values(ids);
  let myId: string | undefined;
  if (myEmail) {
    myId = await findUserIdByEmail(myEmail);
    if (!myId) {
      console.warn(
        `akun ${myEmail} belum ada. login dulu di app (OTP), lalu jalankan ulang.`,
      );
    } else {
      memberIds.push(myId);
    }
  }
  check(
    "anggota circle",
    await admin.from("circle_members").upsert(
      memberIds.map((user_id) => ({ circle_id: circleId, user_id })),
      { onConflict: "circle_id,user_id", ignoreDuplicates: true },
    ),
  );

  // daily drop hari ini (supaya label telat terhitung), kalau belum ada.
  check(
    "daily drop",
    await admin.from("daily_drops").upsert(
      {
        drop_date: today,
        sent_at: new Date(Date.now() - 2 * 3600_000).toISOString(),
      },
      { onConflict: "drop_date", ignoreDuplicates: true },
    ),
  );
  const drop = must(
    "baca daily drop",
    await admin.from("daily_drops").select("sent_at").eq("drop_date", today)
      .single(),
  );
  const sentAt = new Date(drop.sent_at as string).getTime();

  // catch hari ini: ganti yang lama milik user contoh.
  const catchIds: Record<string, string> = {};
  for (const u of USERS) {
    if (!u.catch) continue;
    const userId = ids[u.key];
    const old = must(
      "catch lama",
      await admin.from("catches").select(
        "id, animal_id, animal_photo_path, selfie_photo_path",
      )
        .eq("user_id", userId).eq("catch_date", today),
    );
    for (const c of old ?? []) {
      await admin.storage.from("catch-photos").remove([
        c.animal_photo_path,
        c.selfie_photo_path,
      ]);
      check(
        "hapus catch lama",
        await admin.from("catches").delete().eq("id", c.id),
      );
      if (c.animal_id) {
        await admin.from("animals").delete().eq("id", c.animal_id);
      }
    }

    const catchId = crypto.randomUUID();
    const folder = `${userId}/${catchId}`;
    for (const kind of ["animal", "selfie"] as const) {
      const bytes = await Deno.readFile(
        new URL(`${u.catch.photo}_${kind}.jpg`, PHOTOS),
      );
      must(
        `upload ${kind} ${u.key}`,
        await admin.storage.from("catch-photos").upload(
          `${folder}/${kind}.jpg`,
          bytes,
          {
            contentType: "image/jpeg",
            upsert: true,
          },
        ),
      );
    }

    const animal = must(
      "hewan",
      await admin.from("animals").insert({
        owner_id: userId,
        ...u.catch.animal,
      }).select("id")
        .single(),
    );
    // Telat = dibuat > 1 jam setelah daily drop; tepat waktu = sebelum itu.
    const wanted = Date.now() - u.catch.minutesAgo * 60_000;
    const createdAt = Math.min(
      Date.now(),
      u.catch.late
        ? Math.max(wanted, sentAt + 61 * 60_000)
        : Math.min(wanted, sentAt + 59 * 60_000),
    );
    check(
      `catch ${u.key}`,
      await admin.from("catches").insert({
        id: catchId,
        user_id: userId,
        animal_id: animal.id,
        animal_photo_path: `${folder}/animal.jpg`,
        selfie_photo_path: `${folder}/selfie.jpg`,
        ai_type: u.catch.animal.animal_type,
        ai_confidence: u.catch.ai_confidence,
        ai_candidates: [u.catch.animal.animal_type],
        ai_personality: u.catch.personality,
        personality: u.catch.personality,
        location_hidden: true,
        is_late: u.catch.late,
        catch_date: today,
        created_at: new Date(createdAt).toISOString(),
      }),
    );
    catchIds[u.key] = catchId;
  }

  // reaksi & komentar antar user contoh
  const reactions = [
    ["raka", "dinda", "like"],
    ["bimo", "dinda", "like"],
    ["sasa", "dinda", "laugh"],
    ["dinda", "raka", "like"],
    ["dinda", "raka", "laugh"],
    ["bimo", "raka", "laugh"],
    ["raka", "bimo", "like"],
  ] as const;
  check(
    "reaksi",
    await admin.from("reactions").insert(
      reactions.map(([from, to, type]) => ({
        catch_id: catchIds[to],
        user_id: ids[from],
        type,
      })),
    ),
  );
  const comments = [
    ["raka", "dinda", "mochi makin gendut aja"],
    ["sasa", "dinda", "pengen ngelus 😭"],
    ["bimo", "raka", "pak kwek ga pernah absen ya"],
  ] as const;
  check(
    "komentar",
    await admin.from("comments").insert(
      comments.map(([from, to, body]) => ({
        catch_id: catchIds[to],
        user_id: ids[from],
        body,
      })),
    ),
  );

  console.log(
    `siap! circle "${CIRCLE.name}" (kode ${CIRCLE.invite_code}), ${
      Object.keys(catchIds).length
    } catch hari ini (${today}).`,
  );
  if (myId) console.log(`akun ${myEmail} sudah jadi anggota circle.`);
  else {console.log(
      "tip: tambahkan email akunmu sebagai argumen supaya ikut masuk circle.",
    );}
}

await main();
