import 'package:flutter/material.dart';

class PrivacyShieldOverlay extends StatelessWidget {
  final Widget child;
  final bool isScreenshotBlocked;

  const PrivacyShieldOverlay({
    super.key,
    required this.child,
    this.isScreenshotBlocked = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        // Diagonal subtle watermark pattern
        IgnorePointer(
          child: Opacity(
            opacity: 0.035,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (context, index) {
                return Transform.rotate(
                  angle: -0.35,
                  child: const Center(
                    child: Text(
                      'DOODLE 🔒',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
