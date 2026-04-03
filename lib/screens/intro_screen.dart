import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import 'splash_decider.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rand = Random();
  final List<_IntroHeart> _hearts = [];

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    for (int i = 0; i < 12; i++) {
      _hearts.add(_IntroHeart(
        x: _rand.nextDouble(),
        size: 14 + _rand.nextDouble() * 20,
        speed: 0.05 + _rand.nextDouble() * 0.1,
        phase: _rand.nextDouble(),
      ));
    }

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const SplashDecider(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Açılamadı: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return Stack(
            children: [
              /// 🌈 PREMIUM GRADIENT
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                      Color(0xFF0F3460),
                      Color(0xFFE94560),
                    ],
                    stops: [0.0, 0.4, 0.75, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              /// 💖 FLOATING HEARTS
              ..._hearts.map((h) {
                final t = (_c.value + h.phase) % 1.0;

                final y = size.height * (1.1 - t);
                final x = size.width * (h.x + sin(t * 2 * pi) * 0.04);

                final opacity = (sin(t * pi)).clamp(0.2, 1.0);
                final scale = 0.8 + (sin(t * pi) * 0.4);

                return Positioned(
                  top: y,
                  left: x,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Icon(
                        Icons.favorite,
                        size: h.size,
                        color: AppTheme.primary.withOpacity(0.8),
                      ),
                    ),
                  ),
                );
              }),

              /// 💎 GLASS CARD
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// ❤️ HEARTBEAT LOGO
                            Transform.scale(
                              scale: 1 + (sin(_c.value * 2 * pi) * 0.08),
                              child: const Icon(
                                Icons.favorite_rounded,
                                size: 64,
                                color: AppTheme.primary,
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// 🔤 TITLE
                            const Text(
                              'YMS',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 22),

                            /// 📝 DESCRIPTION
                            Text(
                              'Bu uygulamanın asıl amacı kız arkadaşım için yapılmış olup,\n'
                              'gün içinde birbirimize küçük hatırlatmalar göndermemizi sağlar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontStyle: FontStyle.italic,
                                height: 1.8,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),

                            const SizedBox(height: 28),

                            /// ✨ DIVIDER
                            Container(
                              height: 1,
                              width: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            /// 👨‍💻 INFO
                            Text(
                              'SELÇUK ŞAHİN tarafından geliştirilmiştir.\n'
                              'Öneri & destek için mail atabilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// 🔗 SOCIAL ICONS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const FaIcon(
                                    FontAwesomeIcons.instagram,
                                    color: Colors.pinkAccent,
                                  ),
                                  onPressed: () => _launch(
                                      'https://instagram.com/selcukshn74'),
                                ),
                                IconButton(
                                  icon: const FaIcon(
                                    FontAwesomeIcons.github,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _launch('https://github.com/Zyix-code'),
                                ),
                                IconButton(
                                  icon: const FaIcon(
                                    FontAwesomeIcons.envelope,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _launch(
                                      'mailto:selcuksahin158@gmail.com'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IntroHeart {
  final double x;
  final double size;
  final double speed;
  final double phase;

  _IntroHeart({
    required this.x,
    required this.size,
    required this.speed,
    required this.phase,
  });
}
