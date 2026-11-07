import { assertEquals } from "jsr:@std/assert@1.0.13";
import type { FcmMessage, SendResult } from "../_shared/fcm.ts";
import {
  type ActivityBatch,
  activityMessage,
  createSendActivityHandler,
  friendMessage,
  joinNames,
  type SendActivityDeps,
  streakMessage,
} from "./handler.ts";

const batch = (over: Partial<ActivityBatch> = {}): ActivityBatch => ({
  token: "tok-alice",
  catchId: "c1",
  animalName: "Milo",
  actorNames: ["dinda"],
  reactions: 1,
  comments: 0,
  lastComment: null,
  ...over,
});

function setup(
  overrides: Partial<SendActivityDeps> = {},
  results: Record<string, SendResult> = {},
) {
  const log = {
    activityClaims: 0,
    streakClaims: 0,
    sent: [] as { token: string; message: FcmMessage }[],
    cleared: [] as string[][],
  };
  const deps: SendActivityDeps = {
    secret: "rahasia",
    claimActivity: () => {
      log.activityClaims++;
      return Promise.resolve([
        batch(),
        batch({ token: "tok-bob", catchId: "c2", comments: 1 }),
      ]);
    },
    claimFriends: () =>
      Promise.resolve([
        {
          token: "tok-dave",
          actorName: "Dave",
          kind: "request",
          actorId: "u-d",
        },
      ]),
    claimStreakReminders: () => {
      log.streakClaims++;
      return Promise.resolve([{ token: "tok-carol", streak: 4 }]);
    },
    clearTokens: (tokens) => {
      log.cleared.push(tokens);
      return Promise.resolve();
    },
    getSender: () => (token, message) => {
      log.sent.push({ token, message });
      return Promise.resolve(results[token] ?? "ok");
    },
    ...overrides,
  };
  return { handler: createSendActivityHandler(deps), log };
}

const post = (body: unknown, auth: string | null = "Bearer rahasia") =>
  new Request("http://localhost/send-activity", {
    method: "POST",
    headers: auth ? { authorization: auth } : {},
    body: JSON.stringify(body),
  });

Deno.test("activity: klaim, kirim per penerima, hapus token mati", async () => {
  const { handler, log } = setup({}, { "tok-bob": "invalid_token" });
  const res = await handler(post({ job: "activity" }));
  assertEquals(await res.json(), {
    status: "sent",
    job: "activity",
    messages: 3,
    delivered: 2,
    invalid: 1,
    failed: 0,
  });
  assertEquals(log.sent.map((s) => s.token), [
    "tok-alice",
    "tok-bob",
    "tok-dave",
  ]);
  assertEquals(log.sent[0].message.data, { type: "activity", catch_id: "c1" });
  assertEquals(log.cleared, [["tok-bob"]]);
  assertEquals(log.streakClaims, 0);
});

Deno.test("streak: klaim pengingat & kirim", async () => {
  const { handler, log } = setup();
  const res = await handler(post({ job: "streak" }));
  assertEquals((await res.json()).messages, 1);
  assertEquals(log.sent[0].token, "tok-carol");
  assertEquals(log.sent[0].message.title, "streak 4 hari lo hampir putus!");
  assertEquals(log.activityClaims, 0);
});

Deno.test("secret salah / job tidak dikenal ditolak", async () => {
  const { handler, log } = setup();
  assertEquals(
    (await handler(post({ job: "activity" }, "Bearer x"))).status,
    401,
  );
  assertEquals((await handler(post({ job: "activity" }, null))).status, 401);
  assertEquals((await handler(post({ job: "spam" }))).status, 400);
  assertEquals(
    (await handler(new Request("http://x", { method: "GET" }))).status,
    405,
  );
  assertEquals(log.activityClaims + log.streakClaims, 0);
});

Deno.test("tanpa secret → 500", async () => {
  const { handler } = setup({ secret: undefined });
  assertEquals((await handler(post({ job: "activity" }))).status, 500);
});

Deno.test("FCM belum diatur → antrean tidak diklaim", async () => {
  const { handler, log } = setup({ getSender: () => null });
  assertEquals(await (await handler(post({ job: "activity" }))).json(), {
    status: "skipped",
    fcm: "not_configured",
  });
  assertEquals(log.activityClaims, 0);
});

Deno.test("klaim gagal → 500", async () => {
  const { handler } = setup({
    claimActivity: () => Promise.reject(new Error("db")),
  });
  assertEquals((await handler(post({ job: "activity" }))).status, 500);
});

Deno.test("joinNames", () => {
  assertEquals(joinNames([]), "teman lo");
  assertEquals(joinNames(["dinda"]), "dinda");
  assertEquals(joinNames(["dinda", "raka"]), "dinda & raka");
  assertEquals(
    joinNames(["dinda", "raka", "sasa", "bima"]),
    "dinda, raka & 2 lainnya",
  );
});

Deno.test("isi notifikasi aktivitas", () => {
  assertEquals(activityMessage(batch()).title, "dinda ngereaksi catch Milo");
  assertEquals(activityMessage(batch()).body, "buka feed buat lihat.");
  const comment = activityMessage(
    batch({ reactions: 0, comments: 2, lastComment: "dinda: lucu bgt" }),
  );
  assertEquals(comment.title, "dinda komentar di catch Milo");
  assertEquals(comment.body, "dinda: lucu bgt");
  assertEquals(
    activityMessage(
      batch({ comments: 1, animalName: null, actorNames: ["a", "b"] }),
    )
      .title,
    "a & b ngereaksi & komentar di catch lo",
  );
  assertEquals(
    activityMessage(batch({ lastComment: "x".repeat(200) })).body.length,
    120,
  );
  assertEquals(activityMessage(batch()).channelId, "activity");
});

Deno.test("isi pengingat streak", () => {
  const m = streakMessage({ token: "t", streak: 2 });
  assertEquals(m.channelId, "streak_reminder");
  assertEquals(m.data, { type: "streak_reminder" });
});

Deno.test("isi notifikasi teman", () => {
  const req = friendMessage({
    token: "t",
    actorName: "Dinda",
    kind: "request",
    actorId: "u1",
  });
  assertEquals(req.title, "Dinda pengen temenan sama lo");
  assertEquals(req.channelId, "friends");
  assertEquals(req.data, { type: "friend", kind: "request", user_id: "u1" });
  assertEquals(
    friendMessage({
      token: "t",
      actorName: "Dinda",
      kind: "accepted",
      actorId: "u1",
    })
      .title,
    "Dinda nerima permintaan teman lo",
  );
});
