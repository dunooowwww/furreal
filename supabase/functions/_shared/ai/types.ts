/** Hasil identify-animal (PRD §6.1), sudah divalidasi. */
export interface AiResult {
  animal_type: string | null;
  confidence: number;
  candidates: string[];
  personality: string | null;
}

/** Foto yang dikirim ke provider. Hanya foto hewan, tidak pernah selfie. */
export interface AiImage {
  base64: string;
  mediaType: "image/jpeg";
}

export interface AiProvider {
  readonly name: ProviderName;
  readonly model: string;
  /** Kembalikan teks/objek mentah dari model; validasi di `validate.ts`. */
  identify(image: AiImage, signal: AbortSignal): Promise<unknown>;
}

export type ProviderName = "mock" | "anthropic" | "openai_compatible";

export type AiErrorCode =
  | "ai_not_configured"
  | "ai_unavailable"
  | "invalid_ai_response"
  | "timeout";

export class AiError extends Error {
  constructor(readonly code: AiErrorCode, message: string) {
    super(message);
    this.name = "AiError";
  }
}

export type FetchFn = typeof fetch;
