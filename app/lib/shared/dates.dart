/// Tanggal hari ini di zona Asia/Jakarta (UTC+7, tanpa DST), sama dengan
/// `public.jakarta_today()` di database.
DateTime jakartaToday([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime.utc(t.year, t.month, t.day);
}

/// Format `yyyy-MM-dd` untuk kolom `date` di Postgres.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
