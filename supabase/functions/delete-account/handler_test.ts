import { assertEquals } from "jsr:@std/assert@1.0.13";
import {
  createDeleteAccountHandler,
  type DeleteAccountDeps,
  REMOVE_BATCH,
} from "./handler.ts";

const USER = "11111111-1111-1111-1111-111111111111";

function setup(
  photos: string[] = [`${USER}/a/animal.jpg`, `${USER}/a/selfie.jpg`],
  overrides: Partial<DeleteAccountDeps> = {},
  avatars: string[] = [],
) {
  const log = {
    removed: [] as string[][],
    buckets: [] as string[],
    deleted: [] as string[],
    steps: [] as string[],
  };
  const deps: DeleteAccountDeps = {
    getUserId: (auth) => Promise.resolve(auth === "Bearer good" ? USER : null),
    listPhotos: (userId, bucket) => {
      if (bucket === "avatars") return Promise.resolve(avatars);
      log.steps.push(`list ${userId}`);
      return Promise.resolve(photos);
    },
    removePhotos: (bucket, paths) => {
      log.steps.push("remove");
      log.buckets.push(bucket);
      log.removed.push(paths);
      return Promise.resolve();
    },
    deleteUser: (userId) => {
      log.steps.push("delete");
      log.deleted.push(userId);
      return Promise.resolve();
    },
    ...overrides,
  };
  return { handler: createDeleteAccountHandler(deps), log };
}

const post = (auth: string | null = "Bearer good") =>
  new Request("http://localhost/delete-account", {
    method: "POST",
    headers: auth ? { authorization: auth } : {},
  });

Deno.test("sukses: foto dihapus dulu, lalu akun", async () => {
  const { handler, log } = setup();
  const res = await handler(post());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { deleted: true, photos: 2 });
  assertEquals(log.steps, [`list ${USER}`, "remove", "delete"]);
  assertEquals(log.removed, [[`${USER}/a/animal.jpg`, `${USER}/a/selfie.jpg`]]);
  assertEquals(log.deleted, [USER]);
});

Deno.test("tanpa foto: langsung hapus akun", async () => {
  const { handler, log } = setup([]);
  const res = await handler(post());
  assertEquals(await res.json(), { deleted: true, photos: 0 });
  assertEquals(log.steps, [`list ${USER}`, "delete"]);
});

Deno.test(`foto dihapus per ${REMOVE_BATCH}`, async () => {
  const photos = Array.from(
    { length: 250 },
    (_, i) => `${USER}/c${i}/animal.jpg`,
  );
  const { handler, log } = setup(photos);
  await handler(post());
  assertEquals(log.removed.map((b) => b.length), [100, 100, 50]);
});

Deno.test("tanpa JWT valid → 401, tidak ada yang dihapus", async () => {
  for (const auth of [null, "Bearer salah"]) {
    const { handler, log } = setup();
    const res = await handler(post(auth));
    assertEquals(res.status, 401);
    assertEquals((await res.json()).error.code, "unauthorized");
    assertEquals(log.steps, []);
  }
});

Deno.test("bukan POST → 405", async () => {
  const { handler } = setup();
  const res = await handler(new Request("http://localhost/x"));
  assertEquals(res.status, 405);
});

Deno.test("hapus foto gagal → akun TIDAK dihapus (bisa dicoba lagi)", async () => {
  const { handler, log } = setup(undefined, {
    removePhotos: () => Promise.reject(new Error("storage mati")),
  });
  const res = await handler(post());
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error.code, "photos_failed");
  assertEquals(log.deleted, []);
});

Deno.test("path di luar folder user → berhenti tanpa menghapus apa pun", async () => {
  const { handler, log } = setup([
    `${USER}/a/animal.jpg`,
    "22222222-2222-2222-2222-222222222222/b/animal.jpg",
  ]);
  const res = await handler(post());
  assertEquals((await res.json()).error.code, "photos_failed");
  assertEquals(log.removed, []);
  assertEquals(log.deleted, []);
});

Deno.test("hapus user gagal → 500 delete_failed", async () => {
  const { handler } = setup(undefined, {
    deleteUser: () => Promise.reject(new Error("auth mati")),
  });
  const res = await handler(post());
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error.code, "delete_failed");
});

Deno.test("foto profil (avatars) ikut dihapus", async () => {
  const { handler, log } = setup(undefined, {}, [`${USER}/f.jpg`]);
  const res = await handler(post());
  assertEquals(await res.json(), { deleted: true, photos: 3 });
  assertEquals(log.buckets, ["catch-photos", "avatars"]);
  assertEquals(log.removed[1], [`${USER}/f.jpg`]);
});

Deno.test("path asing di avatars → tidak ada yang dihapus", async () => {
  const { handler, log } = setup(undefined, {}, [
    "22222222-2222-2222-2222-222222222222/f.jpg",
  ]);
  const res = await handler(post());
  assertEquals((await res.json()).error.code, "photos_failed");
  assertEquals(log.removed, []);
  assertEquals(log.deleted, []);
});
