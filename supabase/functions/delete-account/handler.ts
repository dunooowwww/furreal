/** Storage API menerima maksimal sekian path per panggilan remove. */
export const REMOVE_BATCH = 100;

/** Bucket berisi file milik user ({uid}/...): foto catch dan foto profil. */
export const PHOTO_BUCKETS = ["catch-photos", "avatars"] as const;
export type PhotoBucket = typeof PHOTO_BUCKETS[number];

/** Semua akses ke luar (auth, DB, storage) diinjeksi supaya bisa dites. */
export interface DeleteAccountDeps {
  getUserId(authorization: string | null): Promise<string | null>;
  /** Semua file user di bucket itu (account_photo_paths / account_avatar_paths). */
  listPhotos(userId: string, bucket: PhotoBucket): Promise<string[]>;
  /** Hapus lewat Storage API (DELETE SQL ditolak storage.protect_delete). */
  removePhotos(bucket: PhotoBucket, paths: string[]): Promise<void>;
  /** auth.admin.deleteUser: data DB ikut terhapus lewat FK cascade. */
  deleteUser(userId: string): Promise<void>;
}

const MESSAGES: Record<string, string> = {
  method_not_allowed: "pakai POST.",
  unauthorized: "harus login dulu.",
  photos_failed: "gagal menghapus foto. coba lagi ya.",
  delete_failed: "gagal menghapus akun. coba lagi ya.",
};

const STATUS: Record<string, number> = {
  method_not_allowed: 405,
  unauthorized: 401,
  photos_failed: 500,
  delete_failed: 500,
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const errorResponse = (code: string) =>
  json({ error: { code, message: MESSAGES[code] } }, STATUS[code]);

export function createDeleteAccountHandler(deps: DeleteAccountDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return errorResponse("method_not_allowed");

    // Hanya akun pemilik JWT yang bisa dihapus; tidak ada parameter user id.
    const userId = await deps.getUserId(req.headers.get("authorization"));
    if (!userId) return errorResponse("unauthorized");

    // Foto dulu: kalau gagal, akun belum dihapus dan user bisa mencoba lagi.
    let count = 0;
    try {
      // Daftar semua bucket dulu: path asing di bucket mana pun → tidak ada
      // yang dihapus sama sekali.
      const prefix = `${userId}/`;
      const lists: [PhotoBucket, string[]][] = [];
      for (const bucket of PHOTO_BUCKETS) {
        const paths = await deps.listPhotos(userId, bucket);
        if (paths.some((p) => !p.startsWith(prefix))) {
          throw new Error("path di luar folder user");
        }
        lists.push([bucket, paths]);
      }
      for (const [bucket, paths] of lists) {
        for (let i = 0; i < paths.length; i += REMOVE_BATCH) {
          await deps.removePhotos(bucket, paths.slice(i, i + REMOVE_BATCH));
        }
        count += paths.length;
      }
    } catch (e) {
      console.error("delete-account: foto", e);
      return errorResponse("photos_failed");
    }

    try {
      await deps.deleteUser(userId);
    } catch (e) {
      console.error("delete-account: user", e);
      return errorResponse("delete_failed");
    }

    return json({ deleted: true, photos: count });
  };
}
