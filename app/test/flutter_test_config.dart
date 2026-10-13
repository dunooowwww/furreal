import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Font dimuat dari assets/google_fonts/, tidak boleh ada akses jaringan.
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
