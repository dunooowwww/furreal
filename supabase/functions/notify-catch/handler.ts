import type { FcmMessage, SendResult } from "../_shared/fcm.ts";

/** Berapa notifikasi dikirim bersamaan. */
export const CONCURRENCY = 20;

export interface Recipient {
  /** Nama tampilan (atau username) pemilik catch. */
  senderName: string;
  token: string;
  /** Penerima sudah catch hari ini (feed-nya sudah terbuka). */
  recipientCaught: boolean;
}

/** Semua akses ke luar (auth, DB, FCM) diinjeksi supaya bisa dites. */
export interface NotifyCatchDeps {
  getUserId(authorization: string | null): Promise<string | null>;
  /**
   * claim_catch_notification(catch, user): sekali per catch hari ini milik
   * user; kosong kalau tidak valid atau sudah pernah dikabarkan.
   */
  claim(catchId: string, userId: string): Promise<Recipient[]>;
  clearTokens(tokens: string[]): Promise<void>;
  /** Pengirim FCM, atau null kalau FCM_SERVICE_ACCOUNT_JSON belum diisi. */
  getSender():
    | ((token: string, message: FcmMessage) => Promise<SendResult>)
    | null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const error = (code: string, message: string, status: number) =>
  json({ error: { code, message } }, status);

/** Isi notifikasi untuk satu penerima (feed terkunci kalau belum catch). */
export function catchMessage(
  recipient: Recipient,
  catchId: string,
): FcmMessage {
  return {
    title: `${recipient.senderName} udah catch!`,
    body: recipient.recipientCaught
      ? "lihat hewan temuannya di feed."
      : "catch dulu buat lihat hewan temuannya.",
    channelId: "friend_catch",
    // Kabar basi tidak berguna: buang kalau HP offline lebih dari 6 jam.
    ttlSeconds: 6 * 60 * 60,
    data: { type: "friend_catch", catch_id: catchId },
  };
}

export function createNotifyCatchHandler(deps: NotifyCatchDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") {
      return error("method_not_allowed", "pakai POST.", 405);
    }
    const userId = await deps.getUserId(req.headers.get("authorization"));
    if (!userId) return error("unauthorized", "harus login dulu.", 401);

    let catchId: unknown;
    try {
      catchId = (await req.json())?.catch_id;
    } catch {
      catchId = undefined;
    }
    if (typeof catchId !== "string" || !UUID.test(catchId)) {
      return error("bad_request", "catch_id tidak valid.", 400);
    }

    // Klaim dulu (sekali per catch) supaya tidak bisa dipakai buat spam.
    let recipients: Recipient[];
    try {
      recipients = await deps.claim(catchId, userId);
    } catch (e) {
      console.error("notify-catch: klaim", e);
      return error("internal", "gagal menyiapkan notifikasi.", 500);
    }
    if (recipients.length === 0) return json({ status: "skipped" });

    let send: ReturnType<NotifyCatchDeps["getSender"]>;
    try {
      send = deps.getSender();
    } catch (e) {
      console.error("notify-catch: FCM_SERVICE_ACCOUNT_JSON", e);
      return json({ status: "skipped", fcm: "config_error" });
    }
    if (!send) return json({ status: "skipped", fcm: "not_configured" });

    // Satu token bisa muncul sekali saja walau berbagi beberapa circle.
    const unique = [
      ...new Map(recipients.map((r) => [r.token, r])).values(),
    ];
    const counts = { delivered: 0, invalid: 0, failed: 0 };
    const invalid: string[] = [];
    for (let i = 0; i < unique.length; i += CONCURRENCY) {
      const batch = unique.slice(i, i + CONCURRENCY);
      const results = await Promise.all(
        batch.map((r) => send(r.token, catchMessage(r, catchId as string))),
      );
      results.forEach((result, j) => {
        if (result === "ok") counts.delivered++;
        else if (result === "invalid_token") {
          counts.invalid++;
          invalid.push(batch[j].token);
        } else counts.failed++;
      });
    }
    if (invalid.length > 0) {
      await deps.clearTokens(invalid).catch((e) =>
        console.error("notify-catch: hapus token", e)
      );
    }
    return json({ status: "sent", recipients: unique.length, ...counts });
  };
}
