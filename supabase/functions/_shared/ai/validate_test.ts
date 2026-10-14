import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import { AiError } from "./types.ts";
import { parseAiJson, validateAiResult } from "./validate.ts";

Deno.test("hasil valid dinormalisasi ke skema PRD §6.1", () => {
  const result = validateAiResult({
    animal_type: "  Kucing ",
    confidence: 0.937,
    candidates: ["Musang", "kucing", "", "musang"],
    personality:
      "Si Penjaga Parkiran.   Hobi: tidur di jok motor orang. Kalimat ketiga dibuang.",
  });
  assertEquals(result, {
    animal_type: "kucing",
    confidence: 0.94,
    candidates: ["kucing", "musang"],
    personality: "si penjaga parkiran. hobi: tidur di jok motor orang.",
  });
});

Deno.test("tidak ada hewan → semua kosong", () => {
  assertEquals(
    validateAiResult({
      animal_type: null,
      confidence: 0.3,
      candidates: ["x"],
      personality: "abc.",
    }),
    { animal_type: null, confidence: 0, candidates: [], personality: null },
  );
  assertEquals(validateAiResult({ animal_type: "  " }).animal_type, null);
});

Deno.test("confidence dalam persen diubah ke 0..1", () => {
  const r = validateAiResult({
    animal_type: "ayam",
    confidence: 88,
    candidates: [],
    personality: null,
  });
  assertEquals(r.confidence, 0.88);
  assertEquals(r.candidates, ["ayam"]);
});

Deno.test("JSON dalam blok kode atau teks tetap terbaca", () => {
  const raw =
    'oke ini hasilnya:\n```json\n{"animal_type":"burung","confidence":0.8,"candidates":["burung"],"personality":"suka nyanyi."}\n```';
  assertEquals(validateAiResult(raw).animal_type, "burung");
  assertEquals(parseAiJson({ a: 1 }), { a: 1 });
});

Deno.test("jawaban tidak valid → AiError invalid_ai_response", () => {
  const bad: unknown[] = [
    "bukan json sama sekali",
    "{ rusak",
    [],
    42,
    { animal_type: 7, confidence: 0.5 },
    { animal_type: "kucing", confidence: "tinggi" },
    { animal_type: "kucing", confidence: 150 },
    { animal_type: "kucing", confidence: 0.5, candidates: "kucing" },
    { animal_type: "kucing", confidence: 0.5, candidates: [], personality: 3 },
    { animal_type: "x".repeat(41), confidence: 0.5 },
  ];
  for (const raw of bad) {
    const e = assertThrows(() => validateAiResult(raw), AiError);
    assertEquals(e.code, "invalid_ai_response", JSON.stringify(raw));
  }
});

Deno.test("kartu kepribadian dipotong ke batas panjang", () => {
  const r = validateAiResult({
    animal_type: "kucing",
    confidence: 0.9,
    candidates: [],
    personality: "a".repeat(400),
  });
  assertEquals(r.personality!.length, 280);
});
