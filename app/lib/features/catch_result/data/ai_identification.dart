/// Hasil identify-animal (PRD §6.1).
class AiIdentification {
  const AiIdentification({
    required this.animalType,
    required this.confidence,
    required this.candidates,
    required this.personality,
  });

  /// Melempar [AiFailure] kalau bentuk respons tidak sesuai.
  factory AiIdentification.fromJson(Object? json) {
    if (json is! Map) throw const AiFailure('invalid_ai_response');
    final type = json['animal_type'];
    final confidence = json['confidence'];
    final candidates = json['candidates'];
    final personality = json['personality'];
    if ((type != null && type is! String) ||
        confidence is! num ||
        candidates is! List ||
        (personality != null && personality is! String)) {
      throw const AiFailure('invalid_ai_response');
    }
    return AiIdentification(
      animalType: type as String?,
      confidence: confidence.toDouble(),
      candidates: candidates.whereType<String>().toList(),
      personality: personality as String?,
    );
  }

  final String? animalType;
  final double confidence;
  final List<String> candidates;
  final String? personality;

  int get confidencePercent => (confidence * 100).round();
}

/// AI gagal; [code] dari Edge Function (mis. `rate_limited`, `timeout`).
class AiFailure implements Exception {
  const AiFailure(this.code);

  final String code;

  String get message => switch (code) {
    'rate_limited' => 'jatah AI hari ini udah habis. isi jenisnya sendiri ya.',
    'timeout' => 'AI kelamaan mikir. isi jenisnya sendiri ya.',
    _ => 'AI lagi nggak bisa ngenalin. isi jenisnya sendiri ya.',
  };

  @override
  String toString() => 'AiFailure($code)';
}
