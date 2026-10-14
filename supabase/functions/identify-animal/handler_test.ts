import { assertEquals } from "jsr:@std/assert@1.0.13";
import { createMockProvider } from "../_shared/ai/providers/mock.ts";
import { AiError, type AiProvider } from "../_shared/ai/types.ts";
import {
  type CallOutcome,
  createIdentifyHandler,
  type IdentifyDeps,
  RateLimitedError,
} from "./handler.ts";

const USER = "11111111-1111-1111-1111-111111111111";
const CATCH = "aaaaaaaa-0000-4000-8000-000000000001";

function setup(overrides: Partial<IdentifyDeps> = {}) {
  const log = {
    claims: [] as Parameters<IdentifyDeps["claimCall"]>[0][],
    finished: [] as CallOutcome[],
    downloads: [] as string[],
  };
  const deps: IdentifyDeps = {
    getUserId: (auth) => Promise.resolve(auth === "Bearer good" ? USER : null),
    claimCall: (input) => {
      log.claims.push(input);
      return Promise.resolve("call-1");
    },
    finishCall: (_id, outcome) => {
      log.finished.push(outcome);
      return Promise.resolve();
    },
    downloadPhoto: (path) => {
      log.downloads.push(path);
      return Promise.resolve(new Uint8Array([0xff, 0xd8, 0xff]));
    },
    getProvider: () => createMockProvider({ delayMs: 0 }),
    ...overrides,
  };
  return { handler: createIdentifyHandler(deps), log };
}

const post = (body: unknown, auth = "Bearer good") =>
  new Request("http://localhost/identify-animal", {
    method: "POST",
    headers: { authorization: auth, "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const provider = (
  identify: AiProvider["identify"],
  name: AiProvider["name"] = "anthropic",
): AiProvider => ({
  name,
  model: "test-model",
  identify,
});

Deno.test("sukses: hanya foto hewan dikirim, hasil divalidasi & disimpan", async () => {
  const { handler, log } = setup();
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    animal_type: "kucing",
    confidence: 0.94,
    candidates: ["kucing", "musang"],
    personality: "si penjaga parkiran. hobi: tidur di jok motor orang.",
  });
  assertEquals(log.downloads, [`${USER}/${CATCH}/animal.jpg`]);
  assertEquals(log.finished[0].status, "ok");
  // mode mock: tanpa batas harian
  assertEquals(log.claims[0].dailyLimit, null);
  assertEquals(log.claims[0].provider, "mock");
});

Deno.test("provider asli: batas 5 per hari dikirim ke claim", async () => {
  const { handler, log } = setup({
    getProvider: () =>
      provider(() =>
        Promise.resolve({
          animal_type: "ayam",
          confidence: 0.8,
          candidates: [],
          personality: null,
        })
      ),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 200);
  assertEquals(log.claims[0].dailyLimit, 5);
  assertEquals(log.claims[0].model, "test-model");
});

Deno.test("tanpa login → 401", async () => {
  const { handler, log } = setup();
  const res = await handler(post({ catch_id: CATCH }, "Bearer jelek"));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error.code, "unauthorized");
  assertEquals(log.claims.length, 0);
});

Deno.test("body tidak valid → 400", async () => {
  const { handler } = setup();
  for (
    const body of ["bukan json", { catch_id: "123" }, {}, {
      catch_id: CATCH.toUpperCase(),
    }]
  ) {
    const res = await handler(post(body));
    assertEquals(res.status, 400, JSON.stringify(body));
    assertEquals((await res.json()).error.code, "bad_request");
  }
});

Deno.test("bukan POST → 405", async () => {
  const { handler } = setup();
  const res = await handler(new Request("http://localhost/identify-animal"));
  assertEquals(res.status, 405);
});

Deno.test("jatah habis → 429 rate_limited, AI tidak dipanggil", async () => {
  let called = false;
  const { handler } = setup({
    claimCall: () => Promise.reject(new RateLimitedError()),
    getProvider: () => provider(() => (called = true, Promise.resolve({}))),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error, {
    code: "rate_limited",
    message: "jatah AI hari ini udah habis. isi jenisnya sendiri ya.",
  });
  assertEquals(called, false);
});

Deno.test("foto belum ada → 404 photo_not_found, dicatat sebagai error", async () => {
  const { handler, log } = setup({
    downloadPhoto: () => Promise.resolve(null),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 404);
  assertEquals(log.finished, [{ status: "error", code: "photo_not_found" }]);
});

Deno.test("AI lewat batas waktu → 504 timeout", async () => {
  const { handler, log } = setup({
    timeoutMs: 20,
    getProvider: () =>
      provider((_img, signal) =>
        new Promise((_resolve, reject) =>
          signal.addEventListener("abort", () => reject(signal.reason))
        )
      ),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 504);
  assertEquals((await res.json()).error.code, "timeout");
  assertEquals(log.finished, [{ status: "error", code: "timeout" }]);
});

Deno.test("jawaban AI tidak sesuai skema → 502 invalid_ai_response", async () => {
  const { handler, log } = setup({
    getProvider: () =>
      provider(() => Promise.resolve("maaf, aku nggak bisa jawab JSON")),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error.code, "invalid_ai_response");
  assertEquals(log.finished[0], {
    status: "error",
    code: "invalid_ai_response",
  });
});

Deno.test("provider error tak terduga → 502 ai_unavailable", async () => {
  const { handler } = setup({
    getProvider: () =>
      provider(() => Promise.reject(new TypeError("network down"))),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error.code, "ai_unavailable");
});

Deno.test("hewan tidak terdeteksi → 200 dengan animal_type null", async () => {
  const { handler } = setup({
    getProvider: () =>
      provider(() =>
        Promise.resolve({
          animal_type: null,
          confidence: 0,
          candidates: [],
          personality: null,
        })
      ),
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).animal_type, null);
});

Deno.test("provider belum diatur → 500 ai_not_configured", async () => {
  const { handler, log } = setup({
    getProvider: () => {
      throw new AiError("ai_not_configured", "AI_API_KEY belum diisi");
    },
  });
  const res = await handler(post({ catch_id: CATCH }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error.code, "ai_not_configured");
  assertEquals(log.claims.length, 0);
});
