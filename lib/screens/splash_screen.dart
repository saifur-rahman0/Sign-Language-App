import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../sign_language_app.dart';
import '../theme/neu_theme.dart';
import '../services/offline_inference_service.dart';

/// Premium Animated Neumorphic Splash Screen with App Logo
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _pulseAnim;

  String _loadingStatus = 'মডেল ও লাইব্রেরি প্রস্তুত করা হচ্ছে...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animCtrl.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initial delay for smooth intro
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _progress = 0.35;
      _loadingStatus = 'অন-ডিভাইস এআই ইঞ্জিন লোড হচ্ছে...';
    });

    // 2. Initialize on-device ONNX runtime & label mappings
    try {
      await OfflineInferenceService.initialize();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _progress = 0.75;
      _loadingStatus = '৪০১টি শব্দের ডিকশনারি লোড হচ্ছে...';
    });

    // 3. Final completion
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _loadingStatus = 'প্রস্তুত!';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    // Smooth navigation to main app
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, anim, secondaryAnim) => const SignLanguageApp(),
        transitionsBuilder: (_, anim, secondaryAnim, child) {
          return FadeTransition(
            opacity: anim,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: NeuColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              NeuColors.highContrast ? Brightness.light : Brightness.dark,
        ),
        child: Stack(
          children: [
            // Ambient soft background glow circles
            Positioned(
              top: -size.width * 0.25,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      NeuColors.accent.withValues(alpha: 0.12),
                      NeuColors.background.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.width * 0.25,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      NeuColors.accent.withValues(alpha: 0.08),
                      NeuColors.background.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Center Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo Card with Animated Scaling & Fade
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: AnimatedBuilder(
                          animation: _animCtrl,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnim.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 140,
                            height: 140,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: NeuColors.background,
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: neuRaisedShadows(depth: 1.5),
                            ),
                            child: Image.asset(
                              'assets/images/BdSL_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.sign_language_rounded,
                                size: 68,
                                color: NeuColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title & Subtitle
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          Text(
                            'BdSL',
                            style: GoogleFonts.nunito(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: NeuColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'বাংলা ইশারা ভাষা অনুবাদক',
                            style: GoogleFonts.hindSiliguri(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: NeuColors.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI-Powered Bangla Sign Language Recognition',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: NeuColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Progress Indicator & Status
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          // Neumorphic Inset Progress Bar
                          Container(
                            width: 220,
                            height: 8,
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: NeuColors.background,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: neuInsetShadows(),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeInOut,
                                    width: constraints.maxWidth * _progress,
                                    decoration: BoxDecoration(
                                      color: NeuColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: NeuColors.accent
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _loadingStatus,
                            style: GoogleFonts.hindSiliguri(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NeuColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Bottom Pill Badge
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: NeuColors.background,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: neuRaisedShadows(depth: 0.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 14, color: NeuColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              '401 Signs · On-Device & Cloud AI',
                              style: GoogleFonts.nunito(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: NeuColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
