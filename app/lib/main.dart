import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'app/missing_config_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Font sudah di-bundle; jangan unduh dari internet saat runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(_fontLicenses);

  if (!AppConfig.hasSupabase) {
    runApp(const MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: FurrealApp()));
}

Stream<LicenseEntry> _fontLicenses() async* {
  const fonts = {
    'bricolagegrotesque': 'Bricolage Grotesque',
    'geist': 'Geist',
    'geistmono': 'Geist Mono',
  };
  for (final MapEntry(:key, :value) in fonts.entries) {
    final license = await rootBundle.loadString(
      'assets/google_fonts/OFL-$key.txt',
    );
    yield LicenseEntryWithLineBreaks([value], license);
  }
}
