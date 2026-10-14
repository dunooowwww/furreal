import type { AiProvider } from "../types.ts";

/** Hasil tiruan bergiliran untuk development, tanpa API. */
export const MOCK_RESULTS = [
  {
    animal_type: "kucing",
    confidence: 0.94,
    candidates: ["kucing", "musang"],
    personality: "si penjaga parkiran. hobi: tidur di jok motor orang.",
  },
  {
    animal_type: "ayam",
    confidence: 0.88,
    candidates: ["ayam", "burung puyuh"],
    personality:
      "bangun paling pagi se-kompleks. tugas utamanya ngecek tiap butir nasi yang jatuh.",
  },
  {
    animal_type: "burung",
    confidence: 0.81,
    candidates: ["burung", "merpati"],
    personality:
      "suka nongkrong di kabel listrik. kalau diajak ngobrol, langsung pura-pura sibuk.",
  },
] as const;

export function createMockProvider(
  options: { delayMs?: number } = {},
): AiProvider {
  const delayMs = options.delayMs ?? 1500;
  let next = 0;
  return {
    name: "mock",
    model: "mock",
    async identify(_image, signal) {
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(resolve, delayMs);
        signal.addEventListener("abort", () => {
          clearTimeout(timer);
          reject(signal.reason);
        }, { once: true });
      });
      const result = MOCK_RESULTS[next % MOCK_RESULTS.length];
      next++;
      return structuredClone(result);
    },
  };
}
