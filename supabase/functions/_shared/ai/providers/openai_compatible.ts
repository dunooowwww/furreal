import { SYSTEM_PROMPT, USER_TEXT } from "../prompt.ts";
import { AiError, type AiProvider, type FetchFn } from "../types.ts";

/**
 * Endpoint format OpenAI Chat Completions (mis. Sumopod).
 * `baseUrl` biasanya diakhiri `/v1`; model wajib menerima input gambar.
 */
export function createOpenAiCompatibleProvider(config: {
  apiKey: string;
  model: string;
  baseUrl: string;
  fetch?: FetchFn;
}): AiProvider {
  const baseUrl = config.baseUrl.replace(/\/+$/, "");
  const doFetch = config.fetch ?? fetch;

  return {
    name: "openai_compatible",
    model: config.model,
    async identify(image, signal) {
      const response = await doFetch(`${baseUrl}/chat/completions`, {
        method: "POST",
        signal,
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${config.apiKey}`,
        },
        body: JSON.stringify({
          model: config.model,
          // Model "berpikir" (mis. Gemini Flash) memakai jatah ini juga untuk
          // reasoning; terlalu kecil → jawaban kosong/terpotong.
          max_tokens: 2048,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            {
              role: "user",
              content: [
                { type: "text", text: USER_TEXT },
                {
                  type: "image_url",
                  image_url: {
                    url: `data:${image.mediaType};base64,${image.base64}`,
                  },
                },
              ],
            },
          ],
        }),
      });

      if (!response.ok) {
        await response.body?.cancel();
        throw new AiError(
          "ai_unavailable",
          `provider AI menolak permintaan (HTTP ${response.status})`,
        );
      }

      const data = await response.json();
      if (data?.choices?.[0]?.finish_reason === "length") {
        throw new AiError("invalid_ai_response", "jawaban AI terpotong");
      }
      const content = data?.choices?.[0]?.message?.content;
      // Sebagian gateway mengembalikan content berupa array bagian teks.
      const text = Array.isArray(content)
        ? content.map((p: { text?: string }) => p?.text ?? "").join("")
        : content;
      if (typeof text !== "string" || text.trim() === "") {
        throw new AiError("invalid_ai_response", "jawaban AI kosong");
      }
      return text;
    },
  };
}
