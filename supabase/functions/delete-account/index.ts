// delete-account: hapus akun pemilik JWT beserta semua datanya (PRD §8).
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { createDeleteAccountHandler } from "./handler.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const handler = createDeleteAccountHandler({
  async getUserId(authorization) {
    const token = authorization?.replace(/^Bearer\s+/i, "");
    if (!token) return null;
    const { data, error } = await admin.auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },

  async listPhotos(userId, bucket) {
    const rpc = bucket === "avatars"
      ? "account_avatar_paths"
      : "account_photo_paths";
    const { data, error } = await admin.rpc(rpc, { p_user_id: userId });
    if (error) throw error;
    return (data as string[] | null) ?? [];
  },

  async removePhotos(bucket, paths) {
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) throw error;
  },

  async deleteUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
});

Deno.serve(handler);
