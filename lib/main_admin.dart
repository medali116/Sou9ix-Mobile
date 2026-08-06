import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/admin/routing/app_router.dart';
import 'package:sou9ix/firebase_options.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/features/settings/service/shop_code_storage.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android/iOS/Windows auto-configure natively (google-services.json per
  // flavor for Android); only Web has no such mechanism and needs explicit
  // options — DefaultFirebaseOptions.currentPlatform would throw on the
  // other platforms since only `web` was ever generated (see
  // firebase_options.dart), so this is deliberately conditional rather
  // than using `.currentPlatform` directly.
  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.web : null,
  );
  final shopCode = await ShopCodeStorage.read();
  runApp(
    ProviderScope(
      overrides: [shopCodeProvider.overrideWith((ref) => shopCode)],
      child: const Sou9ixAdminApp(),
    ),
  );
}

class Sou9ixAdminApp extends StatelessWidget {
  const Sou9ixAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sou9ix Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
