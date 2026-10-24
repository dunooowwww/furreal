import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/dates.dart';

/// Lama jendela "tepat waktu" setelah daily drop turun (sama dengan server).
const onTimeWindow = Duration(hours: 1);

enum DropPhase {
  /// Drop hari ini belum turun. Sejak M10 tetap boleh catch (ditandai
  /// "sebelum drop").
  waiting,

  /// Kurang dari 1 jam sejak drop: catch tepat waktu.
  onTime,

  /// Lewat 1 jam: masih boleh catch, tapi ditandai telat.
  late,
}

/// Label waktu catch, dihitung server saat posting (`catches.timing`, M10).
enum CatchTiming {
  early('early', 'sebelum drop'),
  onTime('on_time', 'tepat waktu'),
  late('late', 'telat');

  const CatchTiming(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static CatchTiming fromDb(String? value, {bool isLate = false}) =>
      values.where((t) => t.dbValue == value).firstOrNull ??
      (isLate ? late : onTime);
}

/// Daily drop hari ini (Asia/Jakarta). [sentAt] null = belum turun.
class DailyDrop {
  const DailyDrop({this.sentAt});

  static const waiting = DailyDrop();

  final DateTime? sentAt;

  DropPhase phaseAt(DateTime now) {
    final sent = sentAt;
    if (sent == null) return DropPhase.waiting;
    return now.isAfter(sent.add(onTimeWindow))
        ? DropPhase.late
        : DropPhase.onTime;
  }

  /// Sisa waktu tepat-waktu (nol kalau sudah telat atau belum turun).
  Duration remainingAt(DateTime now) {
    final sent = sentAt;
    if (sent == null) return Duration.zero;
    final left = sent.add(onTimeWindow).difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

/// `42:07` (menit:detik), untuk hitung mundur tepat-waktu.
String formatCountdown(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

abstract interface class DailyDropRepository {
  Future<DailyDrop> today();
}

class SupabaseDailyDropRepository implements DailyDropRepository {
  SupabaseDailyDropRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DailyDrop> today() async {
    // RLS hanya menampilkan drop yang sudah turun; jamnya tidak bisa dibaca.
    final row = await _client
        .from('daily_drops')
        .select('sent_at')
        .eq('drop_date', isoDate(jakartaToday()))
        .maybeSingle();
    final sentAt = row?['sent_at'] as String?;
    return DailyDrop(sentAt: sentAt == null ? null : DateTime.parse(sentAt));
  }
}
