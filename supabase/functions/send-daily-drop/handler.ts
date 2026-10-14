import type { FcmMessage, SendResult } from "../_shared/fcm.ts";

/** Berapa notifikasi dikirim bersamaan. */
export const CONCURRENCY = 20;

export const DROP_MESSAGE: Omit<FcmMessage, "data"> = {
  title: "waktunya catch!",
  body: "daily drop udah turun. lo punya 1 jam buat catch tepat waktu.",
  channelId: "daily_drop",
  // HP yang offline lama tetap dapat kabar drop hari itu, tapi tidak besoknya.
  ttlSeconds: 12 * 60 * 60,
};

/** Semua akses ke luar (DB, FCM) diinjeksi supaya bisa dites. */
export interface DailyDropDeps {
  /** Env DAILY_DROP_SECRET; sama dengan Vault daily_drop_secret. */
  secret: string | undefined;
  /** claim_daily_drop(): sent_at (ISO) kalau berhasil, null kalau sudah terkirim / belum waktunya. */
  claimDrop(): Promise<string | null>;
  listTokens(): Promise<string[]>;
  clearTokens(tokens: string[]): Promise<void>;
  /** Pengirim FCM, atau null kalau FCM_SERVICE_ACCOUNT_JSON belum diisi. */
  getSender():
    | ((token: string, message: FcmMessage) => Promise<SendResult>)
    | null;
  /** Tanggal drop (Asia/Jakarta) untuk payload data. */
  today(): string;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const error = (code: string, message: string, status: number) =>
  json({ error: { code, message } }, status);

function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

export function createDailyDropHandler(deps: DailyDropDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") {
      return error("method_not_allowed", "pakai POST.", 405);
    }
    if (!deps.secret) {
      console.error("send-daily-drop: DAILY_DROP_SECRET belum diisi");
      return error("not_configured", "DAILY_DROP_SECRET belum diatur.", 500);
    }
    const auth = req.headers.get("authorization") ?? "";
    if (!safeEqual(auth, `Bearer ${deps.secret}`)) {
      return error("unauthorized", "secret tidak cocok.", 401);
    }

    let sentAt: string | null;
    try {
      sentAt = await deps.claimDrop();
    } catch (e) {
      console.error("send-daily-drop: claim", e);
      return error("internal", "gagal mengklaim drop.", 500);
    }
    // Panggilan ganda dari cron (atau drop belum waktunya): jangan kirim lagi.
    if (!sentAt) return json({ status: "skipped" });

    // Drop sudah turun (catch terbuka) walau notifikasi gagal dikirim.
    let send: ReturnType<DailyDropDeps["getSender"]>;
    try {
      send = deps.getSender();
    } catch (e) {
      console.error("send-daily-drop: FCM_SERVICE_ACCOUNT_JSON", e);
      return json({ status: "sent", sent_at: sentAt, fcm: "config_error" });
    }
    if (!send) {
      console.warn("send-daily-drop: FCM belum diatur, notifikasi dilewati");
      return json({ status: "sent", sent_at: sentAt, fcm: "not_configured" });
    }

    let tokens: string[];
    try {
      tokens = await deps.listTokens();
    } catch (e) {
      console.error("send-daily-drop: token", e);
      return json({ status: "sent", sent_at: sentAt, fcm: "token_error" });
    }

    const message: FcmMessage = {
      ...DROP_MESSAGE,
      data: { type: "daily_drop", drop_date: deps.today() },
    };
    const counts = { delivered: 0, invalid: 0, failed: 0 };
    const invalid: string[] = [];
    for (let i = 0; i < tokens.length; i += CONCURRENCY) {
      const batch = tokens.slice(i, i + CONCURRENCY);
      const results = await Promise.all(batch.map((t) => send(t, message)));
      results.forEach((result, j) => {
        if (result === "ok") counts.delivered++;
        else if (result === "invalid_token") {
          counts.invalid++;
          invalid.push(batch[j]);
        } else counts.failed++;
      });
    }

    if (invalid.length > 0) {
      await deps.clearTokens(invalid).catch((e) =>
        console.error("send-daily-drop: hapus token", e)
      );
    }

    return json({
      status: "sent",
      sent_at: sentAt,
      fcm: "sent",
      tokens: tokens.length,
      ...counts,
    });
  };
}
