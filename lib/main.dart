import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/routing/app_router.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: Sou9ixApp()));
}

class Sou9ixApp extends StatelessWidget {
  const Sou9ixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sou9ix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
