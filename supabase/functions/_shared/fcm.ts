// Firebase Cloud Messaging HTTP v1 tanpa SDK: token OAuth dari service account
// (JWT RS256 lewat WebCrypto) + messages:send.

export const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

export interface ServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
  tokenUri: string;
}

export class FcmConfigError extends Error {}

/** Baca FCM_SERVICE_ACCOUNT_JSON (file JSON service account dari Firebase). */
export function parseServiceAccount(json: string): ServiceAccount {
  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(json);
  } catch {
    throw new FcmConfigError("FCM_SERVICE_ACCOUNT_JSON bukan JSON valid");
  }
  const { project_id, client_email, private_key, token_uri } = raw;
  if (
    typeof project_id !== "string" || typeof client_email !== "string" ||
    typeof private_key !== "string"
  ) {
    throw new FcmConfigError(
      "FCM_SERVICE_ACCOUNT_JSON butuh project_id, client_email, private_key",
    );
  }
  return {
    projectId: project_id,
    clientEmail: client_email,
    privateKey: private_key,
    tokenUri: typeof token_uri === "string" ? token_uri : DEFAULT_TOKEN_URI,
  };
}

export interface FcmMessage {
  title: string;
  body: string;
  /** Payload data (semua nilai string, aturan FCM). */
  data: Record<string, string>;
  /** Channel Android (dibuat app di MainActivity). */
  channelId: string;
  /** Berapa lama FCM menyimpan pesan kalau HP offline. */
  ttlSeconds: number;
}

/** ok, token tidak valid (hapus), atau gagal sementara (biarkan). */
export type SendResult = "ok" | "invalid_token" | "error";

export interface FcmClient {
  send(token: string, message: FcmMessage): Promise<SendResult>;
}

const encoder = new TextEncoder();

export function base64Url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? encoder.encode(data) : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/** JWT assertion untuk grant jwt-bearer Google OAuth. */
export async function signServiceAccountJwt(
  account: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.clientEmail,
    scope: FCM_SCOPE,
    aud: account.tokenUri,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const input = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(input),
  );
  return `${input}.${base64Url(new Uint8Array(signature))}`;
}

/** Error FCM yang berarti token tidak akan pernah valid lagi. */
export function isInvalidTokenError(status: number, body: unknown): boolean {
  const error = (body as { error?: Record<string, unknown> })?.error;
  const details = Array.isArray(error?.details) ? error.details : [];
  const codes = details
    .map((d) => (d as { errorCode?: unknown })?.errorCode)
    .filter((c): c is string => typeof c === "string");
  if (codes.includes("UNREGISTERED") || codes.includes("SENDER_ID_MISMATCH")) {
    return true;
  }
  if (status === 404) return true;
  // INVALID_ARGUMENT juga dipakai untuk payload salah; hapus token hanya kalau
  // pesannya memang soal token, supaya bug payload tidak menghapus semua token.
  const message = typeof error?.message === "string" ? error.message : "";
  return status === 400 && /registration token/i.test(message);
}

export function createFcmClient(
  account: ServiceAccount,
  options: { fetch?: typeof fetch; now?: () => number } = {},
): FcmClient {
  const doFetch = options.fetch ?? fetch;
  const now = options.now ?? Date.now;
  let cached: { token: string; expiresAt: number } | undefined;

  async function accessToken(): Promise<string> {
    if (cached && cached.expiresAt - 60_000 > now()) return cached.token;
    const assertion = await signServiceAccountJwt(
      account,
      Math.floor(now() / 1000),
    );
    const res = await doFetch(account.tokenUri, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    const body = await res.json().catch(() => null);
    if (!res.ok || typeof body?.access_token !== "string") {
      throw new Error(`token OAuth FCM gagal (${res.status})`);
    }
    cached = {
      token: body.access_token,
      expiresAt: now() + (Number(body.expires_in) || 3600) * 1000,
    };
    return cached.token;
  }

  const url =
    `https://fcm.googleapis.com/v1/projects/${account.projectId}/messages:send`;

  async function post(token: string, message: FcmMessage) {
    return doFetch(url, {
      method: "POST",
      headers: {
        authorization: `Bearer ${await accessToken()}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: message.title, body: message.body },
          data: message.data,
          android: {
            priority: "HIGH",
            ttl: `${message.ttlSeconds}s`,
            notification: {
              channel_id: message.channelId,
              tag: message.channelId,
            },
          },
        },
      }),
    });
  }

  return {
    async send(token, message) {
      try {
        let res = await post(token, message);
        if (res.status === 401) {
          // Token OAuth kedaluwarsa lebih cepat dari perkiraan: ambil baru sekali.
          await res.body?.cancel();
          cached = undefined;
          res = await post(token, message);
        }
        if (res.ok) {
          await res.body?.cancel();
          return "ok";
        }
        const body = await res.json().catch(() => null);
        if (isInvalidTokenError(res.status, body)) return "invalid_token";
        console.warn("fcm: kirim gagal", res.status, JSON.stringify(body));
        return "error";
      } catch (e) {
        console.error("fcm: kirim gagal", e);
        return "error";
      }
    },
  };
}
