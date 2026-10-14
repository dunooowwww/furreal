// send-daily-drop: turunkan daily drop hari ini & kirim notifikasi FCM (PRD §6.2).
// Dipanggil dispatch_daily_drop() (pg_cron tiap menit) dengan Bearer DAILY_DROP_SECRET.
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import {
  createFcmClient,
  type FcmClient,
  parseServiceAccount,
} from "../_shared/fcm.ts";
import { createDailyDropHandler } from "./handler.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Client (dan token OAuth-nya) di-cache selama env sama.
let cached: { json: string; client: FcmClient } | undefined;
function getClient(): FcmClient | null {
  const json = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")?.trim();
  if (!json) return null;
  if (cached?.json !== json) {
    cached = { json, client: createFcmClient(parseServiceAccount(json)) };
  }
  return cached.client;
}

const handler = createDailyDropHandler({
  secret: Deno.env.get("DAILY_DROP_SECRET"),

  async claimDrop() {
    const { data, error } = await admin.rpc("claim_daily_drop");
    if (error) throw error;
    return (data as string | null) ?? null;
  },

  async listTokens() {
    const { data, error } = await admin.rpc("fcm_tokens");
    if (error) throw error;
    return (data as string[] | null) ?? [];
  },

  async clearTokens(tokens) {
    const { error } = await admin.rpc("clear_fcm_tokens", { p_tokens: tokens });
    if (error) throw error;
  },

  getSender() {
    const client = getClient();
    return client ? (token, message) => client.send(token, message) : null;
  },

  today() {
    // Asia/Jakarta = UTC+7 tanpa DST.
    return new Date(Date.now() + 7 * 3600_000).toISOString().slice(0, 10);
  },
});

Deno.serve(handler);
