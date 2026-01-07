import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quiz_app/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Logic moved to TweenAnimationBuilder's onEnd
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.splashGradientStart,
              AppColors.splashGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo Glowing Effect
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.circleInner,
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.accentColorHighOpacity,
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: AppColors.accentColorLowOpacity,
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 60,
                    color: AppColors.iconPink,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'QUIZ MOJO',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textWhite,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                'COMPETE. CONQUER. WIN.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey,
                  letterSpacing: 3.0,
                ),
              ),

              const Spacer(flex: 4),

              // Animated Loading Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(seconds: 3),
                  onEnd: () {
                    if (FirebaseAuth.instance.currentUser != null) {
                      context.go('/home');
                    } else {
                      context.go('/login');
                    }
                  },
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BAŞLATILIYOR...',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(value * 100).toInt()}%',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Custom Progress Bar
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.progressBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.accentColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.accentColorMediumOpacity,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Spacer(flex: 1),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: AppColors.textGreyLowOpacity,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Secured by Mojo',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textGreyLowOpacity,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
