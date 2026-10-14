// Helper bersama skrip DEVELOPMENT (seed_dev_*.ts). Khusus Supabase lokal.
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const url = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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

/** Klien service role (melewati RLS). Jangan pernah dipakai di luar lokal. */
export const admin = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const PHOTOS = new URL("./seed_photos/", import.meta.url);

/** Nama foto contoh di `seed_photos/` (`<key>_animal.jpg`, `<key>_selfie.jpg`). */
export type SamplePhoto = "mochi" | "pakkwek" | "kiko";

/** Ambil `data` dari hasil supabase-js, keluar dengan pesan kalau error. */
export function must<T>(
  label: string,
  result: { data: T; error: unknown },
): NonNullable<T> {
  if (result.error || result.data == null) {
    console.error(`gagal ${label}:`, result.error ?? "data kosong");
    Deno.exit(1);
  }
  return result.data as NonNullable<T>;
}

/** Seperti must(), tapi `data` boleh null (mis. insert tanpa select). */
export function check<T>(
  label: string,
  result: { data: T; error: unknown },
): T {
  if (result.error) {
    console.error(`gagal ${label}:`, result.error);
    Deno.exit(1);
  }
  return result.data;
}

/** Tanggal Asia/Jakarta (UTC+7) [daysAgo] hari lalu, format yyyy-MM-dd. */
export function jakartaDate(daysAgo = 0): string {
  return new Date(Date.now() + 7 * 3600_000 - daysAgo * 86_400_000)
    .toISOString()
    .slice(0, 10);
}

export async function findUserIdByEmail(
  email: string,
): Promise<string | undefined> {
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
      user.email?.toLowerCase() === email.toLowerCase()
    );
    if (found) return found.id;
    if (data.users.length < 200) return undefined;
  }
}

/** Upload foto contoh ke `{userId}/{catchId}/animal.jpg` & `selfie.jpg`. */
export async function uploadSamplePhotos(
  userId: string,
  catchId: string,
  photo: SamplePhoto,
): Promise<{ animal: string; selfie: string }> {
  const paths = {
    animal: `${userId}/${catchId}/animal.jpg`,
    selfie: `${userId}/${catchId}/selfie.jpg`,
  };
  for (const kind of ["animal", "selfie"] as const) {
    const bytes = await Deno.readFile(new URL(`${photo}_${kind}.jpg`, PHOTOS));
    must(
      `upload ${paths[kind]}`,
      await admin.storage.from("catch-photos").upload(paths[kind], bytes, {
        contentType: "image/jpeg",
        upsert: true,
      }),
    );
  }
  return paths;
}
