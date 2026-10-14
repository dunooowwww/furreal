/// "baru aja", "2 mnt lalu", "3 jam lalu", "kemarin", "4 hari lalu".
String relativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'baru aja';
  if (diff.inHours < 1) return '${diff.inMinutes} mnt lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  return '${diff.inDays} hari lalu';
}

/// 40 → "40m", 65 → "1j 5m", 120 → "2j".
String shortDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}j' : '${h}j ${m}m';
}
