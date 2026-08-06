import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/features/settings/service/shop_code_storage.dart';

/// The Caissier app's splash screen — same look as the Admin app's, but
/// the destination depends on whether this device has already been linked
/// to a shop: first launch ever goes to `/shop-code` to ask for it, every
/// launch after that goes straight to `/login`.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () async {
      final savedCode = await ShopCodeStorage.read();
      if (!mounted) return;
      context.go(savedCode == null ? '/shop-code' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.inkGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.45),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  )
                  .animate()
                  .scale(
                    duration: 650.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                  )
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 28),
              const Text(
                    'Sou9ix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text(
                'SMART POS SOLUTION',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              const SizedBox(height: 56),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.tealLight.withValues(alpha: 0.9),
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
