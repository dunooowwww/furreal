import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Halaman detail (kartu koleksi, riwayat): tombol kembali di kiri atas,
/// tombol back / gestur back Android juga menutupnya.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FurrealColors.background,
      appBar: AppBar(
        backgroundColor: FurrealColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          key: const Key('detail-back'),
          tooltip: 'kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title, style: FurrealText.mono(fontSize: 13)),
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}
