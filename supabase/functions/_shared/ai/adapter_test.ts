import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1.0.13";
import { createAiProvider, toBase64 } from "./adapter.ts";
import { MOCK_RESULTS } from "./providers/mock.ts";
import { AiError } from "./types.ts";
import { validateAiResult } from "./validate.ts";

const image = { base64: "AAAA", mediaType: "image/jpeg" as const };
const signal = () => new AbortController().signal;
const env = (vars: Record<string, string>) => (name: string) => vars[name];

/** fetch palsu: catat request, balas dengan [body] JSON. Tidak ada jaringan. */
function fakeFetch(body: unknown, status = 200) {
  // deno-lint-ignore no-explicit-any -- body JSON bebas bentuk, cuma diperiksa di test
  const calls: { url: string; init: RequestInit; body: any }[] = [];
  const fn = ((url: string, init: RequestInit) => {
    calls.push({ url, init, body: JSON.parse(init.body as string) });
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as unknown as typeof fetch;
  return { fn, calls };
}

Deno.test("default provider = mock, tanpa key", () => {
  const p = createAiProvider(env({}), { mockDelayMs: 0 });
  assertEquals(p.name, "mock");
});

Deno.test("mock: hasil bergiliran kucing → ayam → burung → kucing", async () => {
  const p = createAiProvider(env({ AI_PROVIDER: "mock" }), { mockDelayMs: 0 });
  const types = [];
  for (let i = 0; i < 4; i++) {
    types.push(validateAiResult(await p.identify(image, signal())).animal_type);
  }
  assertEquals(types, ["kucing", "ayam", "burung", "kucing"]);
  for (const r of MOCK_RESULTS) {
    // setiap hasil mock lolos validasi apa adanya, lengkap dengan kepribadian
    assertEquals(
      validateAiResult(structuredClone(r)),
      structuredClone(r) as never,
    );
  }
});

Deno.test("mock: delay bisa dibatalkan (timeout)", async () => {
  const p = createAiProvider(env({}), { mockDelayMs: 10_000 });
  const c = new AbortController();
  const pending = p.identify(image, c.signal);
  c.abort(new Error("timeout"));
  await assertRejects(() => pending, Error, "timeout");
});

Deno.test("env tidak lengkap → ai_not_configured", () => {
  const cases: Record<string, string>[] = [
    { AI_PROVIDER: "anthropic" },
    { AI_PROVIDER: "openai_compatible", AI_API_KEY: "k", AI_MODEL: "m" },
    {
      AI_PROVIDER: "openai_compatible",
      AI_API_KEY: "k",
      AI_BASE_URL: "https://x/v1",
    },
    { AI_PROVIDER: "gemini", AI_API_KEY: "k" },
  ];
  for (const vars of cases) {
    const e = assertThrows(() => createAiProvider(env(vars)), AiError);
    assertEquals(e.code, "ai_not_configured", JSON.stringify(vars));
  }
});

Deno.test("anthropic: request Messages API dengan gambar + structured outputs", async () => {
  const { fn, calls } = fakeFetch({
    stop_reason: "end_turn",
    content: [
      { type: "thinking", thinking: "" },
      {
        type: "text",
        text:
          '{"animal_type":"kucing","confidence":0.9,"candidates":["kucing"],"personality":"halo."}',
      },
    ],
  });
  const p = createAiProvider(
    env({ AI_PROVIDER: "anthropic", AI_API_KEY: "sk-test" }),
    { fetch: fn },
  );
  assertEquals(p.model, "claude-haiku-5-5");

  const raw = await p.identify(image, signal());
  assertEquals(validateAiResult(raw).animal_type, "kucing");

  const [call] = calls;
  assertEquals(call.url, "https://api.anthropic.com/v1/messages");
  const headers = call.init.headers as Record<string, string>;
  assertEquals(headers["x-api-key"], "sk-test");
  assertEquals(headers["anthropic-version"], "2023-06-01");
  assertEquals(call.body.model, "claude-haiku-5-5");
  assertEquals(call.body.messages[0].content[0], {
    type: "image",
    source: { type: "base64", media_type: "image/jpeg", data: "AAAA" },
  });
  assertEquals(call.body.output_config.format.type, "json_schema");
  assertEquals(call.body.output_config.effort, "low");
  assertEquals(typeof call.body.system, "string");
});

Deno.test("anthropic: AI_MODEL dan AI_BASE_URL dari env dipakai", async () => {
  const { fn, calls } = fakeFetch({
    stop_reason: "end_turn",
    content: [{ type: "text", text: "{}" }],
  });
  const p = createAiProvider(
    env({
      AI_PROVIDER: "anthropic",
      AI_API_KEY: "k",
      AI_MODEL: "claude-x",
      AI_BASE_URL: "https://proxy.test/",
    }),
    { fetch: fn },
  );
  await p.identify(image, signal());
  assertEquals(calls[0].url, "https://proxy.test/v1/messages");
  assertEquals(calls[0].body.model, "claude-x");
});

Deno.test("anthropic: HTTP error dan refusal → ai_unavailable", async () => {
  for (
    const [body, status] of [[{ error: {} }, 529], [{
      stop_reason: "refusal",
      content: [],
    }, 200]] as const
  ) {
    const { fn } = fakeFetch(body, status);
    const p = createAiProvider(
      env({ AI_PROVIDER: "anthropic", AI_API_KEY: "k" }),
      { fetch: fn },
    );
    const e = await assertRejects(() => p.identify(image, signal()), AiError);
    assertEquals(e.code, "ai_unavailable");
  }
});

Deno.test("openai_compatible: request chat/completions dengan image_url (mis. Sumopod)", async () => {
  const { fn, calls } = fakeFetch({
    choices: [{
      message: {
        content:
          '```json\n{"animal_type":"ayam","confidence":0.7,"candidates":[],"personality":"petok."}\n```',
      },
    }],
  });
  const p = createAiProvider(
    env({
      AI_PROVIDER: "openai_compatible",
      AI_API_KEY: "sk-sumo",
      AI_BASE_URL: "https://ai.example.com/v1/",
      AI_MODEL: "vision-model",
    }),
    { fetch: fn },
  );
  const raw = await p.identify(image, signal());
  assertEquals(validateAiResult(raw).animal_type, "ayam");

  const [call] = calls;
  assertEquals(call.url, "https://ai.example.com/v1/chat/completions");
  assertEquals(
    (call.init.headers as Record<string, string>).authorization,
    "Bearer sk-sumo",
  );
  assertEquals(call.body.model, "vision-model");
  assertEquals(call.body.messages[0].role, "system");
  assertEquals(call.body.messages[1].content[1], {
    type: "image_url",
    image_url: { url: "data:image/jpeg;base64,AAAA" },
  });
});

Deno.test("openai_compatible: content berupa array bagian teks", async () => {
  const { fn } = fakeFetch({
    choices: [{
      message: {
        content: [{ type: "text", text: '{"animal_type":"cicak",' }, {
          type: "text",
          text: '"confidence":0.6,"candidates":[],"personality":null}',
        }],
      },
    }],
  });
  const p = createAiProvider(
    env({
      AI_PROVIDER: "openai_compatible",
      AI_API_KEY: "k",
      AI_BASE_URL: "https://x/v1",
      AI_MODEL: "m",
    }),
    { fetch: fn },
  );
  assertEquals(
    validateAiResult(await p.identify(image, signal())).animal_type,
    "cicak",
  );
});

Deno.test("toBase64 sama dengan btoa dan aman untuk data besar", () => {
  const small = new TextEncoder().encode("furreal");
  assertEquals(toBase64(small), btoa("furreal"));
  const big = new Uint8Array(200_000).map((_, i) => i % 256);
  assertEquals(toBase64(big).length, Math.ceil(big.length / 3) * 4);
});
