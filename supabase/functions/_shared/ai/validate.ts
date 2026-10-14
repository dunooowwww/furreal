import { AiError, type AiResult } from "./types.ts";

const MAX_TYPE = 40;
const MAX_CANDIDATES = 5;
const MAX_PERSONALITY = 280;

const invalid = (why: string) =>
  new AiError("invalid_ai_response", `jawaban AI tidak valid: ${why}`);

/** Ambil objek JSON dari teks model (boleh dibungkus ```json ... ```). */
export function parseAiJson(raw: unknown): unknown {
  if (typeof raw !== "string") return raw;
  const text = raw.trim();
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end < start) throw invalid("bukan JSON");
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    throw invalid("JSON rusak");
  }
}

const clean = (s: string) => s.trim().replace(/\s+/g, " ").toLowerCase();

function cleanType(value: unknown, field: string): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") throw invalid(`${field} harus string`);
  const v = clean(value);
  if (v.length > MAX_TYPE) throw invalid(`${field} terlalu panjang`);
  return v === "" ? null : v;
}

/** Maksimal 2 kalimat, huruf kecil. */
function cleanPersonality(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") throw invalid("personality harus string");
  const v = clean(value);
  if (v === "") return null;
  const sentences = v.match(/[^.!?…]+[.!?…]*/g) ?? [v];
  const two = sentences.slice(0, 2).join("").trim();
  return two.length > MAX_PERSONALITY
    ? two.slice(0, MAX_PERSONALITY).trimEnd()
    : two;
}

/** Validasi + normalisasi ke skema PRD §6.1. Lempar AiError kalau tidak valid. */
export function validateAiResult(raw: unknown): AiResult {
  const obj = parseAiJson(raw);
  if (typeof obj !== "object" || obj === null || Array.isArray(obj)) {
    throw invalid("bukan objek");
  }
  const o = obj as Record<string, unknown>;

  const animalType = cleanType(o.animal_type, "animal_type");
  if (animalType === null) {
    return {
      animal_type: null,
      confidence: 0,
      candidates: [],
      personality: null,
    };
  }

  let confidence = o.confidence;
  if (typeof confidence !== "number" || !Number.isFinite(confidence)) {
    throw invalid("confidence harus angka");
  }
  // Sebagian model menjawab persen (94) alih-alih 0.94.
  if (confidence > 1 && confidence <= 100) confidence /= 100;
  if (confidence < 0 || confidence > 1) {
    throw invalid("confidence di luar 0..1");
  }

  const rawCandidates = o.candidates ?? [];
  if (!Array.isArray(rawCandidates)) throw invalid("candidates harus array");
  const candidates = [animalType];
  for (const c of rawCandidates) {
    const v = cleanType(c, "candidates");
    if (v !== null && !candidates.includes(v)) candidates.push(v);
  }

  return {
    animal_type: animalType,
    confidence: Math.round(confidence * 100) / 100,
    candidates: candidates.slice(0, MAX_CANDIDATES),
    personality: cleanPersonality(o.personality),
  };
}
