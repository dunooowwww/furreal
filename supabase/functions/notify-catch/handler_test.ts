import { assertEquals } from "jsr:@std/assert@1.0.13";
import type { FcmMessage, SendResult } from "../_shared/fcm.ts";
import {
  catchMessage,
  CONCURRENCY,
  createNotifyCatchHandler,
  type NotifyCatchDeps,
  type Recipient,
} from "./handler.ts";

const USER = "11111111-1111-1111-1111-111111111111";
const CATCH = "aaaaaaaa-0000-0000-0000-000000000001";

const recipients: Recipient[] = [
  { senderName: "Dinda", token: "a", recipientCaught: true },
  { senderName: "Dinda", token: "b", recipientCaught: false },
];

function setup(
  overrides: Partial<NotifyCatchDeps> = {},
  results: Record<string, SendResult> = {},
  list: Recipient[] = recipients,
) {
  const log = {
    claims: [] as [string, string][],
    sent: [] as { token: string; message: FcmMessage }[],
    cleared: [] as string[][],
  };
  const deps: NotifyCatchDeps = {
    getUserId: (auth) => Promise.resolve(auth === "Bearer good" ? USER : null),
    claim: (catchId, userId) => {
      log.claims.push([catchId, userId]);
      return Promise.resolve(log.claims.length === 1 ? list : []);
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
  return { handler: createNotifyCatchHandler(deps), log };
}

const post = (body: unknown = { catch_id: CATCH }, auth = "Bearer good") =>
  new Request("http://localhost/notify-catch", {
    method: "POST",
    headers: { authorization: auth, "content-type": "application/json" },
    body: JSON.stringify(body),
  });

Deno.test("kirim ke anggota circle, copy beda untuk yang belum catch", async () => {
  const { handler, log } = setup();
  const res = await handler(post());
  assertEquals(await res.json(), {
    status: "sent",
    recipients: 2,
    delivered: 2,
    invalid: 0,
    failed: 0,
  });
  assertEquals(log.claims, [[CATCH, USER]]);
  const byToken = Object.fromEntries(log.sent.map((s) => [s.token, s.message]));
  assertEquals(byToken.a.title, "Dinda udah catch!");
  assertEquals(byToken.a.body, "lihat hewan temuannya di feed.");
  assertEquals(byToken.b.body, "catch dulu buat lihat hewan temuannya.");
  assertEquals(byToken.b.channelId, "friend_catch");
  assertEquals(byToken.b.data, { type: "friend_catch", catch_id: CATCH });
});

Deno.test("panggilan kedua untuk catch yang sama → skipped, tanpa kirim", async () => {
  const { handler, log } = setup();
  await handler(post());
  const res = await handler(post());
  assertEquals(await res.json(), { status: "skipped" });
  assertEquals(log.sent.length, 2);
});

Deno.test("tanpa JWT valid → 401, tidak mengklaim apa pun", async () => {
  const { handler, log } = setup();
  const res = await handler(post(undefined, "Bearer salah"));
  assertEquals(res.status, 401);
  assertEquals(log.claims, []);
});

Deno.test("catch_id tidak valid → 400", async () => {
  for (const body of [{}, { catch_id: "x" }, { catch_id: 1 }, "bukan json"]) {
    const { handler, log } = setup();
    const req = typeof body === "string"
      ? new Request("http://x", {
        method: "POST",
        headers: { authorization: "Bearer good" },
        body,
      })
      : post(body);
    const res = await handler(req);
    assertEquals(res.status, 400);
    assertEquals(log.claims, []);
  }
});

Deno.test("bukan POST → 405", async () => {
  const { handler } = setup();
  const res = await handler(new Request("http://x"));
  assertEquals(res.status, 405);
});

Deno.test("token ganda dikirim sekali; token mati dihapus", async () => {
  const { handler, log } = setup({}, { b: "invalid_token" }, [
    ...recipients,
    { senderName: "Dinda", token: "a", recipientCaught: true },
  ]);
  const res = await handler(post());
  assertEquals((await res.json()).invalid, 1);
  assertEquals(log.sent.map((s) => s.token).sort(), ["a", "b"]);
  assertEquals(log.cleared, [["b"]]);
});

Deno.test(`dikirim per ${CONCURRENCY}`, async () => {
  const many = Array.from({ length: 45 }, (_, i) => ({
    senderName: "x",
    token: `t${i}`,
    recipientCaught: false,
  }));
  const { handler, log } = setup({}, {}, many);
  const res = await handler(post());
  assertEquals((await res.json()).delivered, 45);
  assertEquals(log.sent.length, 45);
});

Deno.test("FCM belum diatur → skipped (catch tetap tersimpan)", async () => {
  const { handler } = setup({ getSender: () => null });
  assertEquals(await (await handler(post())).json(), {
    status: "skipped",
    fcm: "not_configured",
  });
});

Deno.test("klaim gagal → 500", async () => {
  const { handler } = setup({ claim: () => Promise.reject(new Error("db")) });
  assertEquals((await handler(post())).status, 500);
});

Deno.test("catchMessage: judul memakai nama pengirim", () => {
  assertEquals(
    catchMessage(
      { senderName: "raka", token: "t", recipientCaught: false },
      CATCH,
    )
      .title,
    "raka udah catch!",
  );
});
