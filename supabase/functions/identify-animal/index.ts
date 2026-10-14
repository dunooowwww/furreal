// identify-animal: kenali hewan di foto catch lewat adapter AI (PRD §6.1).
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { createAiProvider } from "../_shared/ai/adapter.ts";
import type { AiProvider } from "../_shared/ai/types.ts";
import { createIdentifyHandler, RateLimitedError } from "./handler.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Provider di-cache selama env AI_* sama (giliran mock tetap jalan antar request).
const AI_ENV = ["AI_PROVIDER", "AI_BASE_URL", "AI_MODEL", "AI_API_KEY"];
let cached: { key: string; provider: AiProvider } | undefined;
function getProvider(): AiProvider {
  const key = AI_ENV.map((name) => Deno.env.get(name) ?? "").join("\u0000");
  if (cached?.key !== key) {
    cached = { key, provider: createAiProvider((name) => Deno.env.get(name)) };
  }
  return cached.provider;
}

const handler = createIdentifyHandler({
  async getUserId(authorization) {
    const token = authorization?.replace(/^Bearer\s+/i, "");
    if (!token) return null;
    const { data, error } = await admin.auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },

  async claimCall({ userId, catchId, provider, model, dailyLimit }) {
    const { data, error } = await admin.rpc("claim_ai_call", {
      p_user_id: userId,
      p_catch_id: catchId,
      p_provider: provider,
      p_model: model,
      p_daily_limit: dailyLimit,
    });
    if (error?.code === "FR003") throw new RateLimitedError();
    if (error) throw error;
    return data as string;
  },

  async finishCall(callId, outcome) {
    const update = outcome.status === "ok"
      ? {
        status: "ok",
        animal_type: outcome.result.animal_type,
        confidence: outcome.result.confidence,
        candidates: outcome.result.candidates,
        personality: outcome.result.personality,
      }
      : { status: "error", error_code: outcome.code };
    const { error } = await admin.from("ai_identifications").update(update).eq(
      "id",
      callId,
    );
    if (error) throw error;
  },

  async downloadPhoto(path) {
    const { data, error } = await admin.storage.from("catch-photos").download(
      path,
    );
    if (error || !data) return null;
    return new Uint8Array(await data.arrayBuffer());
  },

  getProvider,
});

Deno.serve(handler);
