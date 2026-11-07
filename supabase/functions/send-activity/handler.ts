import type { FcmMessage, SendResult } from "../_shared/fcm.ts";

/** Berapa notifikasi dikirim bersamaan. */
export const CONCURRENCY = 20;

/** Satu baris claim_activity_notifications(): per penerima & catch. */
export interface ActivityBatch {
  token: string;
  catchId: string;
  animalName: string | null;
  /** Nama pelaku, terbaru dulu. */
  actorNames: string[];
  reactions: number;
  comments: number;
  /** "nama: isi" komentar terbaru, kalau ada. */
  lastComment: string | null;
}

/** Satu baris claim_friend_notifications() (M18). */
export interface FriendNotice {
  token: string;
  actorName: string;
  kind: "request" | "accepted";
  actorId: string;
}

export interface StreakReminder {
  token: string;
  streak: number;
}

/** Semua akses ke luar (DB, FCM) diinjeksi supaya bisa dites. */
export interface SendActivityDeps {
  /** Env DAILY_DROP_SECRET; sama dengan Vault daily_drop_secret. */
  secret: string | undefined;
  claimActivity(): Promise<ActivityBatch[]>;
  claimFriends(): Promise<FriendNotice[]>;
  claimStreakReminders(): Promise<StreakReminder[]>;
  clearTokens(tokens: string[]): Promise<void>;
  /** Pengirim FCM, atau null kalau FCM_SERVICE_ACCOUNT_JSON belum diisi. */
  getSender():
    | ((token: string, message: FcmMessage) => Promise<SendResult>)
    | null;
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

/** "dinda", "dinda & raka", "dinda, raka & 2 lainnya". */
export function joinNames(names: string[]): string {
  if (names.length <= 1) return names[0] ?? "teman lo";
  if (names.length === 2) return `${names[0]} & ${names[1]}`;
  return `${names[0]}, ${names[1]} & ${names.length - 2} lainnya`;
}

const clip = (text: string, max = 120) =>
  text.length > max ? `${text.slice(0, max - 1)}…` : text;

export function activityMessage(batch: ActivityBatch): FcmMessage {
  const who = joinNames(batch.actorNames);
  const what = batch.reactions > 0 && batch.comments > 0
    ? "ngereaksi & komentar di"
    : batch.comments > 0
    ? "komentar di"
    : "ngereaksi";
  const target = batch.animalName ? `catch ${batch.animalName}` : "catch lo";
  return {
    title: `${who} ${what} ${target}`,
    body: batch.lastComment ? clip(batch.lastComment) : "buka feed buat lihat.",
    channelId: "activity",
    ttlSeconds: 6 * 60 * 60,
    data: { type: "activity", catch_id: batch.catchId },
  };
}

export function friendMessage(notice: FriendNotice): FcmMessage {
  return {
    title: notice.kind === "request"
      ? `${notice.actorName} pengen temenan sama lo`
      : `${notice.actorName} nerima permintaan teman lo`,
    body: notice.kind === "request"
      ? "buka furreal buat terima atau tolak."
      : "sekarang kalian bisa lihat catch satu sama lain.",
    channelId: "friends",
    ttlSeconds: 24 * 60 * 60,
    data: { type: "friend", kind: notice.kind, user_id: notice.actorId },
  };
}

export function streakMessage(reminder: StreakReminder): FcmMessage {
  return {
    title: `streak ${reminder.streak} hari lo hampir putus!`,
    body: "belum catch hari ini. cari satu hewan sebelum tengah malam ya.",
    channelId: "streak_reminder",
    // Basi setelah tengah malam WIB (dikirim 20:00).
    ttlSeconds: 4 * 60 * 60,
    data: { type: "streak_reminder" },
  };
}

export function createSendActivityHandler(deps: SendActivityDeps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") {
      return error("method_not_allowed", "pakai POST.", 405);
    }
    if (!deps.secret) {
      console.error("send-activity: DAILY_DROP_SECRET belum diisi");
      return error("not_configured", "DAILY_DROP_SECRET belum diatur.", 500);
    }
    const auth = req.headers.get("authorization") ?? "";
    if (!safeEqual(auth, `Bearer ${deps.secret}`)) {
      return error("unauthorized", "secret tidak cocok.", 401);
    }

    let job: unknown;
    try {
      job = (await req.json())?.job;
    } catch {
      job = undefined;
    }
    if (job !== "activity" && job !== "streak") {
      return error("bad_request", "job harus activity atau streak.", 400);
    }

    // Cek FCM dulu: tanpa FCM jangan klaim, supaya antrean tidak hilang.
    let send: ReturnType<SendActivityDeps["getSender"]>;
    try {
      send = deps.getSender();
    } catch (e) {
      console.error("send-activity: FCM_SERVICE_ACCOUNT_JSON", e);
      return json({ status: "skipped", fcm: "config_error" });
    }
    if (!send) return json({ status: "skipped", fcm: "not_configured" });

    let messages: { token: string; message: FcmMessage }[];
    try {
      messages = job === "activity"
        ? [
          ...(await deps.claimActivity()).map((b) => ({
            token: b.token,
            message: activityMessage(b),
          })),
          ...(await deps.claimFriends()).map((n) => ({
            token: n.token,
            message: friendMessage(n),
          })),
        ]
        : (await deps.claimStreakReminders()).map((r) => ({
          token: r.token,
          message: streakMessage(r),
        }));
    } catch (e) {
      console.error(`send-activity: klaim ${job}`, e);
      return error("internal", "gagal mengklaim notifikasi.", 500);
    }

    const counts = { delivered: 0, invalid: 0, failed: 0 };
    const invalid = new Set<string>();
    for (let i = 0; i < messages.length; i += CONCURRENCY) {
      const batch = messages.slice(i, i + CONCURRENCY);
      const results = await Promise.all(
        batch.map((m) => send(m.token, m.message)),
      );
      results.forEach((result, j) => {
        if (result === "ok") counts.delivered++;
        else if (result === "invalid_token") {
          counts.invalid++;
          invalid.add(batch[j].token);
        } else counts.failed++;
      });
    }
    if (invalid.size > 0) {
      await deps.clearTokens([...invalid]).catch((e) =>
        console.error("send-activity: hapus token", e)
      );
    }
    return json({ status: "sent", job, messages: messages.length, ...counts });
  };
}
