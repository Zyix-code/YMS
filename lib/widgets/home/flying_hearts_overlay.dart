import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeFlyingHeart {
  final int id;
  final double x;
  final AnimationController controller;

  HomeFlyingHeart({
    required this.id,
    required this.x,
    required this.controller,
  });
}

class FlyingHeartsOverlay extends StatelessWidget {
  final List<HomeFlyingHeart> hearts;

  const FlyingHeartsOverlay({
    super.key,
    required this.hearts,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: hearts
          .map((heart) => _FlyingHeartWidget(key: ValueKey(heart.id), heart: heart))
          .toList(growable: false),
    );
  }
}

class _FlyingHeartWidget extends StatelessWidget {
  final HomeFlyingHeart heart;

  const _FlyingHeartWidget({super.key, required this.heart});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: heart.controller,
      builder: (context, _) {
        final t = heart.controller.value;
        final top = MediaQuery.sizeOf(context).height * (0.68 - 0.40 * t);
        final left = MediaQuery.sizeOf(context).width * heart.x;

        return Positioned(
          top: top,
          left: left,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t).clamp(0, 1),
              child: Transform.scale(
                scale: 0.8 + 0.5 * (1 - t),
                child: Icon(
                  Icons.favorite,
                  color: AppTheme.primary.withAlpha(240),
                  size: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
