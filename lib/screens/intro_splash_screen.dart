import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/music_service.dart';
import 'main_screen.dart';

class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({super.key});

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _beat1HapticPlayed = false;
  bool _beat2HapticPlayed = false;
  bool _navigated = false;

  final List<_SparkleParticle> _particles = List.generate(
    28,
    (index) => _SparkleParticle.random(),
  );

  @override
  void initState() {
    super.initState();

    // 1. Kick off concurrent background preloading of Home data immediately!
    MusicService().preloadHomeData();

    // 2. Setup animation controller (shorter on web for rapid desktop responsiveness)
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: kIsWeb ? 1500 : 5000),
    );

    _controller.addListener(() {
      final t = _controller.value;
      if (!kIsWeb) {
        // Trigger haptics during the two heartbeats on mobile
        if (t >= 0.26 && !_beat1HapticPlayed) {
          _beat1HapticPlayed = true;
          HapticFeedback.mediumImpact();
        }
        if (t >= 0.36 && !_beat2HapticPlayed) {
          _beat2HapticPlayed = true;
          HapticFeedback.heavyImpact();
        }
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToMain();
      }
    });

    // Safety fallback timer so user can NEVER be stuck on the splash screen
    Future.delayed(Duration(milliseconds: kIsWeb ? 1800 : 5500), () {
      if (mounted) _navigateToMain();
    });

    _controller.forward();
  }

  void _navigateToMain() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Background ambient radiant aura
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              // Expand ambient bloom during beats
              double bloomScale = 1.0;
              double bloomOpacity = 0.25;

              if (t >= 0.24 && t < 0.34) {
                // Beat 1
                final p = (t - 0.24) / 0.10;
                bloomScale = 1.0 + math.sin(p * math.pi) * 0.45;
                bloomOpacity = 0.25 + math.sin(p * math.pi) * 0.35;
              } else if (t >= 0.34 && t < 0.46) {
                // Beat 2
                final p = (t - 0.34) / 0.12;
                bloomScale = 1.0 + math.sin(p * math.pi) * 0.65;
                bloomOpacity = 0.25 + math.sin(p * math.pi) * 0.50;
              }

              return Center(
                child: Container(
                  width: 320 * bloomScale,
                  height: 320 * bloomScale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFA2D48).withValues(alpha: bloomOpacity),
                        blurRadius: 120,
                        spreadRadius: 40 * bloomScale,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Twinkling floating particles
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _controller.value,
                ),
              );
            },
          ),

          // Main Animation Choreography
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;

              // 1. Entrance Fade & Scale (0.0 -> 0.24: 0 -> 1200ms)
              double entranceOpacity = (t / 0.20).clamp(0.0, 1.0);
              double entranceScale = 0.7 + (0.3 * (t / 0.22).clamp(0.0, 1.0));

              // 2. Heartbeats (0.24 -> 0.46: 1200ms -> 2300ms)
              double heartbeatScale = 1.0;
              if (t >= 0.24 && t < 0.34) {
                // Beat 1 pulse
                final p = (t - 0.24) / 0.10;
                heartbeatScale = 1.0 + (math.sin(p * math.pi) * 0.22);
              } else if (t >= 0.34 && t < 0.46) {
                // Beat 2 deeper pulse
                final p = (t - 0.34) / 0.12;
                heartbeatScale = 1.0 + (math.sin(p * math.pi) * 0.28);
              }

              // 3. Leftward Glide along -X axis (0.48 -> 0.70: 2400ms -> 3500ms)
              double xOffset = 0.0;
              if (t >= 0.48) {
                final glideProgress = ((t - 0.48) / 0.22).clamp(0.0, 1.0);
                final curvedGlide = Curves.easeInOutCubic.transform(glideProgress);
                xOffset = -72.0 * curvedGlide;
              }

              // 4. Typography reveal (0.58 -> 0.88: 2900ms -> 4400ms)
              double textOpacity = 0.0;
              double textTranslateX = 20.0;
              if (t >= 0.58) {
                final textProgress = ((t - 0.58) / 0.26).clamp(0.0, 1.0);
                final curvedText = Curves.easeOutCubic.transform(textProgress);
                textOpacity = curvedText;
                textTranslateX = 20.0 * (1.0 - curvedText);
              }

              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Heart Logo with translation and beating scale
                    Transform.translate(
                      offset: Offset(xOffset, 0),
                      child: Opacity(
                        opacity: entranceOpacity,
                        child: Transform.scale(
                          scale: entranceScale * heartbeatScale,
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFA2D48).withValues(alpha: 0.6),
                                  blurRadius: 36,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/dilse_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Typography Reveal on the Right
                    if (t >= 0.52)
                      Transform.translate(
                        offset: Offset(xOffset + textTranslateX + 16, 0),
                        child: Opacity(
                          opacity: textOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // "DilSe" with Shimmering Gradient
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return const LinearGradient(
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFFF6584),
                                      Color(0xFFFA2D48),
                                      Color(0xFFFFB3C1),
                                    ],
                                    stops: [0.0, 0.4, 0.75, 1.0],
                                  ).createShader(bounds);
                                },
                                child: const Text(
                                  'DilSe',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x99FA2D48),
                                        blurRadius: 20,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Subtitle "Suno Dil Se" with musical accent
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.music_note_rounded,
                                    color: Color(0xFFFA2D48),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Suno Dil Se',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Subtle skip button in bottom right corner if user wishes to skip early
          Positioned(
            right: 20,
            bottom: 40,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.value < 0.40) return const SizedBox.shrink();
                return TextButton(
                  onPressed: _navigateToMain,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkleParticle {
  double x;
  double y;
  double radius;
  double speed;
  double alpha;
  double phase;

  _SparkleParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.alpha,
    required this.phase,
  });

  factory _SparkleParticle.random() {
    final rand = math.Random();
    return _SparkleParticle(
      x: rand.nextDouble(),
      y: rand.nextDouble(),
      radius: 1.0 + rand.nextDouble() * 2.5,
      speed: 0.3 + rand.nextDouble() * 0.7,
      alpha: 0.2 + rand.nextDouble() * 0.7,
      phase: rand.nextDouble() * math.pi * 2,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_SparkleParticle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentY = (p.y - (progress * 0.15 * p.speed)) % 1.0;
      final currentX = (p.x + math.sin(p.phase + progress * math.pi * 4) * 0.02) % 1.0;
      final blink = (math.sin(p.phase + progress * math.pi * 6) + 1.0) / 2.0;

      paint.color = const Color(0xFFFF758C).withValues(
        alpha: (p.alpha * blink * 0.8).clamp(0.0, 1.0),
      );

      canvas.drawCircle(
        Offset(currentX * size.width, currentY * size.height),
        p.radius * (0.8 + 0.4 * blink),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
