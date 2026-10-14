import { RESULT_SCHEMA, SYSTEM_PROMPT, USER_TEXT } from "../prompt.ts";
import { AiError, type AiProvider, type FetchFn } from "../types.ts";

export const ANTHROPIC_DEFAULT_MODEL = "claude-haiku-5-5";
export const ANTHROPIC_DEFAULT_BASE_URL = "https://api.anthropic.com";

/** Claude Messages API lewat fetch (tanpa SDK), JSON dipaksa structured outputs. */
export function createAnthropicProvider(config: {
  apiKey: string;
  model?: string;
  baseUrl?: string;
  fetch?: FetchFn;
}): AiProvider {
  const model = config.model || ANTHROPIC_DEFAULT_MODEL;
  const baseUrl = (config.baseUrl || ANTHROPIC_DEFAULT_BASE_URL).replace(
    /\/+$/,
    "",
  );
  const doFetch = config.fetch ?? fetch;

  return {
    name: "anthropic",
    model,
    async identify(image, signal) {
      const response = await doFetch(`${baseUrl}/v1/messages`, {
        method: "POST",
        signal,
        headers: {
          "content-type": "application/json",
          "x-api-key": config.apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model,
          max_tokens: 2048,
          system: SYSTEM_PROMPT,
          messages: [{
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: image.mediaType,
                  data: image.base64,
                },
              },
              { type: "text", text: USER_TEXT },
            ],
          }],
          // Tugas klasifikasi singkat: effort rendah supaya cepat & murah.
          output_config: {
            effort: "low",
            format: { type: "json_schema", schema: RESULT_SCHEMA },
          },
        }),
      });

      if (!response.ok) {
        // Jangan bocorkan isi error provider ke user; cukup status.
        await response.body?.cancel();
        throw new AiError(
          "ai_unavailable",
          `provider AI menolak permintaan (HTTP ${response.status})`,
        );
      }

      const data = await response.json();
      if (data?.stop_reason === "refusal") {
        throw new AiError("ai_unavailable", "AI menolak menjawab foto ini");
      }
      if (data?.stop_reason === "max_tokens") {
        throw new AiError("invalid_ai_response", "jawaban AI terpotong");
      }
      const text = Array.isArray(data?.content)
        ? data.content.find((b: { type?: string }) => b?.type === "text")?.text
        : undefined;
      if (typeof text !== "string") {
        throw new AiError("invalid_ai_response", "jawaban AI kosong");
      }
      return text;
    },
  };
}
