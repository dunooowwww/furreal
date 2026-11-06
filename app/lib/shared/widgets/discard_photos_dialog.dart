import 'package:flutter/material.dart';

/// Konfirmasi sebelum foto catch yang belum diposting dibuang (tutup, back,
/// atau foto ulang). Hewannya mungkin udah kabur, jadi jangan buang diam-diam.
/// Mengembalikan true kalau user memilih membuang.
Future<bool> confirmDiscardPhotos(
  BuildContext context, {
  bool retake = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(retake ? 'foto ulang?' : 'buang catch ini?'),
      content: Text(
        retake
            ? 'foto yang sekarang bakal kebuang, terus mulai lagi dari foto hewan.'
            : 'fotonya belum diposting. kalau keluar sekarang, fotonya kebuang.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('lanjut catch'),
        ),
        TextButton(
          key: const Key('confirm-discard'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            retake ? 'foto ulang' : 'buang',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
