// send-activity: notifikasi reaksi/komentar (antrean) & pengingat streak (M14).
// Dipanggil pg_cron lewat pg_net dengan Bearer DAILY_DROP_SECRET:
// {"job":"activity"} tiap menit kalau ada antrean, {"job":"streak"} 20:00 WIB.
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import {
  createFcmClient,
  type FcmClient,
  parseServiceAccount,
} from "../_shared/fcm.ts";
import {
  type ActivityBatch,
  createSendActivityHandler,
  type FriendNotice,
  type StreakReminder,
} from "./handler.ts";

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

const handler = createSendActivityHandler({
  secret: Deno.env.get("DAILY_DROP_SECRET"),

  async claimActivity() {
    const { data, error } = await admin.rpc("claim_activity_notifications");
    if (error) throw error;
    return ((data ?? []) as {
      token: string;
      catch_id: string;
      animal_name: string | null;
      actor_names: string[];
      reactions: number;
      comments: number;
      last_comment: string | null;
    }[]).map((r): ActivityBatch => ({
      token: r.token,
      catchId: r.catch_id,
      animalName: r.animal_name,
      actorNames: r.actor_names,
      reactions: r.reactions,
      comments: r.comments,
      lastComment: r.last_comment,
    }));
  },

  async claimFriends() {
    const { data, error } = await admin.rpc("claim_friend_notifications");
    if (error) throw error;
    return ((data ?? []) as {
      token: string;
      actor_name: string;
      kind: "request" | "accepted";
      actor_id: string;
    }[]).map((r): FriendNotice => ({
      token: r.token,
      actorName: r.actor_name,
      kind: r.kind,
      actorId: r.actor_id,
    }));
  },

  async claimStreakReminders() {
    const { data, error } = await admin.rpc("claim_streak_reminders");
    if (error) throw error;
    return ((data ?? []) as { token: string; streak: number }[]).map((
      r,
    ): StreakReminder => ({ token: r.token, streak: r.streak }));
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
