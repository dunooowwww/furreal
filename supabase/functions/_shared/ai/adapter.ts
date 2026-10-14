import { createAnthropicProvider } from "./providers/anthropic.ts";
import { createMockProvider } from "./providers/mock.ts";
import { createOpenAiCompatibleProvider } from "./providers/openai_compatible.ts";
import { AiError, type AiProvider, type FetchFn } from "./types.ts";

export type EnvGetter = (name: string) => string | undefined;

/**
 * Pilih provider AI dari env: AI_PROVIDER (default "mock"), AI_BASE_URL,
 * AI_MODEL, AI_API_KEY. Ganti provider cukup lewat env, tanpa ubah kode.
 */
export function createAiProvider(
  env: EnvGetter,
  options: { fetch?: FetchFn; mockDelayMs?: number } = {},
): AiProvider {
  const provider = (env("AI_PROVIDER") || "mock").trim().toLowerCase();
  const apiKey = env("AI_API_KEY")?.trim();
  const model = env("AI_MODEL")?.trim();
  const baseUrl = env("AI_BASE_URL")?.trim();

  const missing = (name: string) =>
    new AiError(
      "ai_not_configured",
      `${name} belum diisi untuk provider ${provider}`,
    );

  switch (provider) {
    case "mock":
      return createMockProvider({ delayMs: options.mockDelayMs });
    case "anthropic":
      if (!apiKey) throw missing("AI_API_KEY");
      return createAnthropicProvider({
        apiKey,
        model,
        baseUrl,
        fetch: options.fetch,
      });
    case "openai_compatible":
      if (!apiKey) throw missing("AI_API_KEY");
      if (!baseUrl) throw missing("AI_BASE_URL");
      if (!model) throw missing("AI_MODEL");
      return createOpenAiCompatibleProvider({
        apiKey,
        model,
        baseUrl,
        fetch: options.fetch,
      });
    default:
      throw new AiError(
        "ai_not_configured",
        `AI_PROVIDER tidak dikenal: ${provider}`,
      );
  }
}

/** Base64 tanpa dependensi (chunk supaya aman untuk foto besar). */
export function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}
