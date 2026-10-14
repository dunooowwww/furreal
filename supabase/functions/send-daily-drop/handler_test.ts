import { assertEquals } from "jsr:@std/assert@1.0.13";
import type { FcmMessage, SendResult } from "../_shared/fcm.ts";
import {
  CONCURRENCY,
  createDailyDropHandler,
  type DailyDropDeps,
} from "./handler.ts";

const SENT_AT = "2026-10-14T07:12:00+00:00";

function setup(
  overrides: Partial<DailyDropDeps> = {},
  results: Record<string, SendResult> = {},
) {
  const log = {
    claims: 0,
    sent: [] as { token: string; message: FcmMessage }[],
    cleared: [] as string[][],
  };
  const deps: DailyDropDeps = {
    secret: "rahasia",
    claimDrop: () => {
      log.claims++;
      return Promise.resolve(log.claims === 1 ? SENT_AT : null);
    },
    listTokens: () => Promise.resolve(["a", "b", "c"]),
    clearTokens: (tokens) => {
      log.cleared.push(tokens);
      return Promise.resolve();
    },
    getSender: () => (token, message) => {
      log.sent.push({ token, message });
      return Promise.resolve(results[token] ?? "ok");
    },
    today: () => "2026-10-14",
    ...overrides,
  };
  return { handler: createDailyDropHandler(deps), log };
}

const post = (auth: string | null = "Bearer rahasia") =>
  new Request("http://localhost/send-daily-drop", {
    method: "POST",
    headers: auth ? { authorization: auth } : {},
    body: JSON.stringify({ drop_date: "2026-10-14" }),
  });

Deno.test("sukses: klaim drop, kirim ke semua token, hapus token mati", async () => {
  const { handler, log } = setup({}, { b: "invalid_token", c: "error" });
  const res = await handler(post());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    status: "sent",
    sent_at: SENT_AT,
    fcm: "sent",
    tokens: 3,
    delivered: 1,
    invalid: 1,
    failed: 1,
  });
  assertEquals(log.sent.map((s) => s.token), ["a", "b", "c"]);
  assertEquals(log.sent[0].message, {
    title: "waktunya catch!",
    body: "daily drop udah turun. lo punya 1 jam buat catch tepat waktu.",
    channelId: "daily_drop",
    ttlSeconds: 43200,
    data: { type: "daily_drop", drop_date: "2026-10-14" },
  });
  // token yang gagal sementara tidak dihapus
  assertEquals(log.cleared, [["b"]]);
});

Deno.test("panggilan kedua (cron ganda) tidak mengirim ulang", async () => {
  const { handler, log } = setup();
  await handler(post());
  const res = await handler(post());
  assertEquals(await res.json(), { status: "skipped" });
  assertEquals(log.sent.length, 3);
});

Deno.test("secret salah / tanpa header → 401, drop tidak diklaim", async () => {
  const { handler, log } = setup();
  for (const auth of [null, "Bearer salah", "Bearer rahasiaX", "rahasia"]) {
    const res = await handler(post(auth));
    assertEquals(res.status, 401);
    assertEquals((await res.json()).error.code, "unauthorized");
  }
  assertEquals(log.claims, 0);
});

Deno.test("DAILY_DROP_SECRET kosong → 500 not_configured", async () => {
  const { handler, log } = setup({ secret: "" });
  const res = await handler(post("Bearer "));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error.code, "not_configured");
  assertEquals(log.claims, 0);
});

Deno.test("bukan POST → 405", async () => {
  const { handler } = setup();
  const res = await handler(new Request("http://localhost/x"));
  assertEquals(res.status, 405);
});

Deno.test("FCM belum diatur: drop tetap turun, notifikasi dilewati", async () => {
  const { handler, log } = setup({ getSender: () => null });
  const res = await handler(post());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    status: "sent",
    sent_at: SENT_AT,
    fcm: "not_configured",
  });
  assertEquals(log.claims, 1);
});

Deno.test("service account rusak: drop tetap turun", async () => {
  const { handler } = setup({
    getSender: () => {
      throw new Error("json rusak");
    },
  });
  const res = await handler(post());
  assertEquals((await res.json()).fcm, "config_error");
});

Deno.test("klaim gagal → 500 tanpa mengirim", async () => {
  const { handler, log } = setup({
    claimDrop: () => Promise.reject(new Error("db mati")),
  });
  const res = await handler(post());
  assertEquals(res.status, 500);
  assertEquals(log.sent.length, 0);
});

Deno.test("tanpa token: tidak ada yang dihapus", async () => {
  const { handler, log } = setup({ listTokens: () => Promise.resolve([]) });
  const res = await handler(post());
  assertEquals((await res.json()).tokens, 0);
  assertEquals(log.cleared, []);
});

Deno.test(`dikirim per ${CONCURRENCY} bersamaan`, async () => {
  let inFlight = 0;
  let peak = 0;
  const tokens = Array.from({ length: 45 }, (_, i) => `t${i}`);
  const { handler } = setup({
    listTokens: () => Promise.resolve(tokens),
    getSender: () => async () => {
      inFlight++;
      peak = Math.max(peak, inFlight);
      await new Promise((r) => setTimeout(r, 1));
      inFlight--;
      return "ok";
    },
  });
  const body = await (await handler(post())).json();
  assertEquals(body.delivered, 45);
  assertEquals(peak, CONCURRENCY);
});
