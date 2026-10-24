// notify-catch: kabari anggota circle bahwa pemilik JWT baru posting catch (M10).
// Dipanggil app setelah create_catch berhasil; sekali per catch (lihat migrasi M10).
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import {
  createFcmClient,
  type FcmClient,
  parseServiceAccount,
} from "../_shared/fcm.ts";
import { createNotifyCatchHandler, type Recipient } from "./handler.ts";

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

const handler = createNotifyCatchHandler({
  async getUserId(authorization) {
    const token = authorization?.replace(/^Bearer\s+/i, "");
    if (!token) return null;
    const { data, error } = await admin.auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },

  async claim(catchId, userId) {
    const { data, error } = await admin.rpc("claim_catch_notification", {
      p_catch_id: catchId,
      p_user_id: userId,
    });
    if (error) throw error;
    return ((data ?? []) as {
      sender_name: string;
      token: string;
      recipient_caught: boolean;
    }[]).map((r): Recipient => ({
      senderName: r.sender_name,
      token: r.token,
      recipientCaught: r.recipient_caught,
    }));
  },

  async clearTokens(tokens) {
    const { error } = await admin.rpc("clear_fcm_tokens", { p_tokens: tokens });
    if (error) throw error;
  },

  getSender() {
    const client = getClient();
    return client ? (token, message) => client.send(token, message) : null;
  },
});

Deno.serve(handler);
