import 'package:flutter/material.dart';

/// Tampil kalau app dijalankan tanpa `--dart-define-from-file=.env.local`.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SUPABASE_URL / SUPABASE_ANON_KEY belum diisi.\n'
              'jalankan: flutter run --dart-define-from-file=.env.local',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
