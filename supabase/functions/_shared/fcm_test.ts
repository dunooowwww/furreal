import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import {
  base64Url,
  createFcmClient,
  FCM_SCOPE,
  FcmConfigError,
  type FcmMessage,
  isInvalidTokenError,
  parseServiceAccount,
  type ServiceAccount,
} from "./fcm.ts";

const MESSAGE: FcmMessage = {
  title: "waktunya catch!",
  body: "isi",
  data: { type: "daily_drop", drop_date: "2026-10-14" },
  channelId: "daily_drop",
  ttlSeconds: 60,
};

/** Service account palsu dengan kunci RSA yang dibuat saat test. */
async function testAccount() {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  const b64 = btoa(String.fromCharCode(...der)).replace(/(.{64})/g, "$1\n");
  const account: ServiceAccount = {
    projectId: "furreal-test",
    clientEmail: "fcm@furreal-test.iam.gserviceaccount.com",
    privateKey:
      `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`,
    tokenUri: "https://oauth2.example/token",
  };
  return { account, publicKey: pair.publicKey };
}

const fromB64Url = (s: string): Uint8Array<ArrayBuffer> =>
  Uint8Array.from(
    atob(s.replace(/-/g, "+").replace(/_/g, "/")),
    (c) => c.charCodeAt(0),
  );

type Call = { url: string; init: RequestInit };

/** fetch palsu: token OAuth + respons FCM yang bisa diatur per panggilan. */
function fakeFetch(fcmResponses: Response[]) {
  const calls: Call[] = [];
  const fn = (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init: init ?? {} });
    if (url === "https://oauth2.example/token") {
      return Promise.resolve(
        Response.json({
          access_token: `akses-${calls.length}`,
          expires_in: 3600,
        }),
      );
    }
    return Promise.resolve(
      fcmResponses.shift() ?? Response.json({ name: "ok" }),
    );
  };
  return { fetch: fn as typeof fetch, calls };
}

const fcmError = (status: number, message: string, errorCode?: string) =>
  Response.json(
    {
      error: {
        code: status,
        message,
        details: errorCode
          ? [{
            "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
            errorCode,
          }]
          : [],
      },
    },
    { status },
  );

Deno.test("parseServiceAccount: field wajib & token_uri default", () => {
  const acc = parseServiceAccount(JSON.stringify({
    project_id: "p",
    client_email: "e",
    private_key: "k",
  }));
  assertEquals(acc.tokenUri, "https://oauth2.googleapis.com/token");
  assertThrows(() => parseServiceAccount("bukan json"), FcmConfigError);
  assertThrows(
    () => parseServiceAccount(JSON.stringify({ project_id: "p" })),
    FcmConfigError,
  );
});

Deno.test("token OAuth: JWT RS256 bertanda tangan valid, lalu kirim pesan v1", async () => {
  const { account, publicKey } = await testAccount();
  const { fetch, calls } = fakeFetch([]);
  const client = createFcmClient(account, {
    fetch,
    now: () => 1_700_000_000_000,
  });

  assertEquals(await client.send("tok-1", MESSAGE), "ok");
  assertEquals(calls.length, 2);

  // 1) token OAuth
  const form = new URLSearchParams(String(calls[0].init.body));
  assertEquals(
    form.get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
  const [h, c, s] = form.get("assertion")!.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(fromB64Url(h))), {
    alg: "RS256",
    typ: "JWT",
  });
  assertEquals(JSON.parse(new TextDecoder().decode(fromB64Url(c))), {
    iss: account.clientEmail,
    scope: FCM_SCOPE,
    aud: account.tokenUri,
    iat: 1_700_000_000,
    exp: 1_700_003_600,
  });
  assert(
    await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      fromB64Url(s),
      new TextEncoder().encode(`${h}.${c}`),
    ),
    "tanda tangan JWT harus valid",
  );

  // 2) messages:send
  assertEquals(
    calls[1].url,
    "https://fcm.googleapis.com/v1/projects/furreal-test/messages:send",
  );
  const headers = new Headers(calls[1].init.headers);
  assertEquals(headers.get("authorization"), "Bearer akses-1");
  assertEquals(JSON.parse(String(calls[1].init.body)), {
    message: {
      token: "tok-1",
      notification: { title: "waktunya catch!", body: "isi" },
      data: { type: "daily_drop", drop_date: "2026-10-14" },
      android: {
        priority: "HIGH",
        ttl: "60s",
        notification: { channel_id: "daily_drop", tag: "daily_drop" },
      },
    },
  });
});

Deno.test("token OAuth di-cache antar pengiriman", async () => {
  const { account } = await testAccount();
  const { fetch, calls } = fakeFetch([]);
  const client = createFcmClient(account, { fetch });
  await client.send("a", MESSAGE);
  await client.send("b", MESSAGE);
  assertEquals(calls.filter((c) => c.url.includes("oauth2")).length, 1);
});

Deno.test("401 → ambil token OAuth baru dan coba sekali lagi", async () => {
  const { account } = await testAccount();
  const { fetch, calls } = fakeFetch([fcmError(401, "expired")]);
  const client = createFcmClient(account, { fetch });
  assertEquals(await client.send("a", MESSAGE), "ok");
  assertEquals(calls.filter((c) => c.url.includes("oauth2")).length, 2);
});

Deno.test("klasifikasi error: token tidak valid vs gagal sementara", async () => {
  const { account } = await testAccount();
  const { fetch } = fakeFetch([
    fcmError(404, "Requested entity was not found.", "UNREGISTERED"),
    fcmError(
      400,
      "The registration token is not a valid FCM registration token",
      "INVALID_ARGUMENT",
    ),
    fcmError(403, "SenderId mismatch", "SENDER_ID_MISMATCH"),
    fcmError(400, "Invalid JSON payload received.", "INVALID_ARGUMENT"),
    fcmError(503, "unavailable", "UNAVAILABLE"),
    fcmError(429, "quota", "QUOTA_EXCEEDED"),
  ]);
  const client = createFcmClient(account, { fetch });
  const results = [];
  for (let i = 0; i < 6; i++) results.push(await client.send(`t${i}`, MESSAGE));
  assertEquals(results, [
    "invalid_token",
    "invalid_token",
    "invalid_token",
    "error", // bug payload tidak boleh menghapus token
    "error",
    "error",
  ]);
});

Deno.test("isInvalidTokenError: 404 tanpa detail dianggap token mati", () => {
  assert(isInvalidTokenError(404, null));
  assert(!isInvalidTokenError(500, null));
});

Deno.test("base64Url tanpa padding", () => {
  assertEquals(base64Url(new Uint8Array([0xfb, 0xff])), "-_8");
});
