import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
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

    for (int i = 0; i < 10; i++) {
      _hearts.add(_IntroHeart(
        x: _rand.nextDouble(),
        size: 14 + _rand.nextDouble() * 18,
        speed: 0.05 + _rand.nextDouble() * 0.08,
        phase: _rand.nextDouble(),
      ));
    }

    Future.delayed(const Duration(milliseconds: 8000), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashDecider()),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
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
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFEDEFF6),
                      Color(0xFFDDE3F0),
                      Color(0xFFC9D2E8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              ..._hearts.map((h) {
                final t = (_c.value + h.phase) % 1.0;
                return Positioned(
                  top: size.height * (1.1 - t),
                  left: size.width * h.x,
                  child: Opacity(
                    opacity: 0.4,
                    child: Icon(
                      Icons.favorite,
                      size: h.size,
                      color: AppTheme.primary,
                    ),
                  ),
                );
              }),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 60,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'YMS',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Bu uygulamanın asıl amacı kız arkadaşım için yapılmış olup,\n'
                              'gün içinde birbirimize küçük hatırlatmalar göndermemizi sağlamaktır.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontStyle: FontStyle.italic,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'Bu program SELÇUK ŞAHİN tarafından geliştirilmiştir.\n'
                              'Herhangi bir arıza, öneri, şikayet için\n'
                              'selcuksahin158@gmail.com adresine mail gönderebilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const FaIcon(
                                    FontAwesomeIcons.instagram,
                                    color: Colors.pink,
                                  ),
                                  onPressed: () => _launch(
                                      'https://instagram.com/selcukshn74'),
                                ),
                                IconButton(
                                  icon: const FaIcon(
                                    FontAwesomeIcons.github,
                                    color: Colors.black,
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
