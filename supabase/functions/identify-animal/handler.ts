import { toBase64 } from "../_shared/ai/adapter.ts";
import {
  AiError,
  type AiProvider,
  type AiResult,
} from "../_shared/ai/types.ts";
import { validateAiResult } from "../_shared/ai/validate.ts";

export const DAILY_LIMIT = 5;
export const TIMEOUT_MS = 15_000;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export class RateLimitedError extends Error {}

export type CallOutcome =
  | { status: "ok"; result: AiResult }
  | { status: "error"; code: string };

/** Semua akses ke luar (auth, DB, storage, AI) diinjeksi supaya bisa dites. */
export interface IdentifyDeps {
  getUserId(authorization: string | null): Promise<string | null>;
  /** Catat panggilan; lempar RateLimitedError kalau jatah habis. */
  claimCall(input: {
    userId: string;
    catchId: string;
    provider: string;
    model: string;
    dailyLimit: number | null;
  }): Promise<string>;
  finishCall(callId: string, outcome: CallOutcome): Promise<void>;
  /** Foto hewan, atau null kalau tidak ada. */
  downloadPhoto(path: string): Promise<Uint8Array | null>;
  /** Bisa melempar AiError("ai_not_configured"). */
  getProvider(): AiProvider;
  timeoutMs?: number;
}

const MESSAGES: Record<string, string> = {
  method_not_allowed: "pakai POST.",
  unauthorized: "harus login dulu.",
  bad_request: "catch_id tidak valid.",
  rate_limited: "jatah AI hari ini udah habis. isi jenisnya sendiri ya.",
  photo_not_found: "foto hewan belum ke-upload.",
  photo_too_large: "foto hewan terlalu besar.",
  timeout: "AI kelamaan mikir. isi jenisnya sendiri ya.",
  invalid_ai_response: "jawaban AI nggak kebaca. isi jenisnya sendiri ya.",
  ai_unavailable: "AI lagi nggak bisa dipakai. isi jenisnya sendiri ya.",
  ai_not_configured: "AI belum diatur di server.",
  internal: "ada yang salah di server.",
};

const STATUS: Record<string, number> = {
  method_not_allowed: 405,
  unauthorized: 401,
  bad_request: 400,
  rate_limited: 429,
  photo_not_found: 404,
  photo_too_large: 413,
  timeout: 504,
  invalid_ai_response: 502,
  ai_unavailable: 502,
  ai_not_configured: 500,
  internal: 500,
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

export const errorResponse = (code: string) =>
  json(
    { error: { code, message: MESSAGES[code] ?? MESSAGES.internal } },
    STATUS[code] ?? 500,
  );

export function createIdentifyHandler(deps: IdentifyDeps) {
  const timeoutMs = deps.timeoutMs ?? TIMEOUT_MS;

  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return errorResponse("method_not_allowed");

    const userId = await deps.getUserId(req.headers.get("authorization"));
    if (!userId) return errorResponse("unauthorized");

    let catchId: unknown;
    try {
      catchId = (await req.json())?.catch_id;
    } catch {
      return errorResponse("bad_request");
    }
    if (typeof catchId !== "string" || !UUID.test(catchId)) {
      return errorResponse("bad_request");
    }

    let provider: AiProvider;
    try {
      provider = deps.getProvider();
    } catch (e) {
      console.error("identify-animal: provider", e);
      return errorResponse(e instanceof AiError ? e.code : "internal");
    }

    let callId: string;
    try {
      callId = await deps.claimCall({
        userId,
        catchId,
        provider: provider.name,
        model: provider.model,
        // Batas harian hanya untuk provider asli (berbayar).
        dailyLimit: provider.name === "mock" ? null : DAILY_LIMIT,
      });
    } catch (e) {
      if (e instanceof RateLimitedError) return errorResponse("rate_limited");
      console.error("identify-animal: claim", e);
      return errorResponse("internal");
    }

    const fail = async (code: string) => {
      await deps.finishCall(callId, { status: "error", code }).catch((e) =>
        console.error("identify-animal: finish", e)
      );
      return errorResponse(code);
    };

    // Hanya foto hewan yang dikirim ke AI, tidak pernah selfie.
    const photo = await deps.downloadPhoto(`${userId}/${catchId}/animal.jpg`);
    if (!photo) return fail("photo_not_found");
    if (photo.byteLength > MAX_PHOTO_BYTES) return fail("photo_too_large");

    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(new AiError("timeout", "timeout")),
      timeoutMs,
    );
    let result: AiResult;
    try {
      const raw = await provider.identify(
        { base64: toBase64(photo), mediaType: "image/jpeg" },
        controller.signal,
      );
      result = validateAiResult(raw);
    } catch (e) {
      if (controller.signal.aborted) return fail("timeout");
      if (e instanceof AiError) {
        console.warn("identify-animal:", e.code, e.message);
        return fail(e.code);
      }
      console.error("identify-animal: provider error", e);
      return fail("ai_unavailable");
    } finally {
      clearTimeout(timer);
    }

    try {
      await deps.finishCall(callId, { status: "ok", result });
    } catch (e) {
      console.error("identify-animal: save", e);
      return errorResponse("internal");
    }
    return json(result);
  };
}
