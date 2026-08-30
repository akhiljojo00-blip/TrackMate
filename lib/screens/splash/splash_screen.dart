import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../auth/auth_gate.dart';

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
  Timer? _progressTimer;
  double _progress = 0.0;

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

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    // Fake progress bar animation
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += 0.02;
        if (_progress > 1.0) _progress = 1.0;
      });
      if (_progress >= 1.0) {
        timer.cancel();
      }
    });

    _timer = Timer(const Duration(milliseconds: 2500), () {
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
        debugPrint('Notice: background tracking state restoration on splash: ');
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient (Deep Void to Midnight Sapphire)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.midnightBackground,
                  Color(0xFF03060C), // Deep Void
                ],
              ),
            ),
          ),
          
          // Glowing Orbits (Faked with multiple blurred circles)
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.solarGold.withValues(alpha: 0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.solarGold.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.solarGold.withValues(alpha: 0.15), width: 1),
              ),
            ),
          ),

          // Main Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Golden Location Pin 3D-like Icon
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Core Glow
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.solarGold.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        // The Pin
                        const Icon(
                          Icons.location_on,
                          size: 110,
                          color: AppColors.solarGold,
                        ),
                        // Inner reflection / highlight
                        const Positioned(
                          top: 15,
                          child: Icon(
                            Icons.circle,
                            size: 32,
                            color: AppColors.midnightBackground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),

                    // App Title
                    const Text(
                      'TRACKMATE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.solarGold,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle / Tagline
                    const Text(
                      'Stay Connected. Stay Safe.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Progress Bar at the bottom
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Loading',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.solarGold, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 4,
                      width: MediaQuery.of(context).size.width * 0.8 * _progress,
                      decoration: BoxDecoration(
                        color: AppColors.solarGold,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.solarGold.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
