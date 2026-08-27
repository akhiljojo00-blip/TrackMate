import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../auth/login_screen.dart';
import '../auth/auth_gate.dart';
import '../map/map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 2000), () {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // If auth state is still resolving, wait briefly
    if (!authProvider.isInitialized) {
      await authProvider.initializationDone.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.userModel == null) {
      await authProvider.refreshProfile().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.user != null) {
      try {
        final locationProvider = context.read<LocationProvider>();
        await locationProvider.restoreTrackingStateIfActive(authProvider.user!.uid);
      } catch (e) {
        debugPrint('Notice: background tracking state restoration on splash: $e');
      }
    }

    if (!mounted) return;

    const targetWidget = AuthGate();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => targetWidget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF070D18), // Deep Midnight OLED Navy
        body: Stack(
          children: [
            // Ambient Radial Sapphire Glow
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF142B58).withValues(alpha: 0.6),
                      const Color(0xFF0A1832).withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Main Center Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hero Master Brand Artwork
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00B4D8).withValues(alpha: 0.25),
                              blurRadius: 36,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/branding/trackmate_logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback radar badge if asset unavailable in test mocks
                                  return Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.primary, Color(0xFF00B4D8)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.radar_rounded,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Accent Radar Icon Overlay for visual depth & test compatibility
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF070D18).withValues(alpha: 0.8),
                                    border: Border.all(
                                      color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.radar_rounded,
                                    size: 14,
                                    color: Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // App Title
                      const Text(
                        'TrackMate',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle / Tagline
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Connect  •  Share  •  Secure',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Right Creator Tag
            Positioned(
              bottom: 24,
              right: 24,
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.code_rounded,
                          size: 14,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Text.rich(
                          const TextSpan(
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.8,
                              color: Colors.white60,
                            ),
                            children: [
                              TextSpan(text: 'Created By '),
                              TextSpan(
                                text: 'AKHIL JOJO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

