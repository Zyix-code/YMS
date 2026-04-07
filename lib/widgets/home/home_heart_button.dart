import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeHeartButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;

  const HomeHeartButton({
    super.key,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: RepaintBoundary(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                  color: AppTheme.primary.withAlpha(70),
                ),
              ],
            ),
            child: Center(
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 96,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
