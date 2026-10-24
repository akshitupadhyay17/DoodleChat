import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      badge: '🎨 PURE DOODLES',
      title: 'Handwritten & Expressive',
      description:
          'No boring keyboards. Every message is a handwritten doodle drawn live on the screen, just like Instagram chat drawing!',
      emoji: '🖌️',
      color: const Color(0xFFFFC72C),
    ),
    OnboardingItem(
      badge: '🪄 THE GOLDEN RULE',
      title: 'Erase Before Replying',
      description:
          'Only one doodle can be sent at a time. The next cannot be sent until the receiver views and completely erases the sender\'s doodle!',
      emoji: '🧽',
      color: const Color(0xFFFF6B81),
    ),
    OnboardingItem(
      badge: '🔒 MAXIMUM PRIVACY',
      title: 'Anti-Screenshot Protection',
      description:
          'Zero screen recording, zero screenshots. Doodles vanish instantly once wiped. What happens in DoodleChat stays in the moment.',
      emoji: '🛡️',
      color: const Color(0xFF00CEC9),
    ),
  ];

  void _finish() {
    ChatService().isOnboarded = true;
    ChatService().saveProfile();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Large Graphic Card
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: item.color, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              item.emoji,
                              style: const TextStyle(fontSize: 78),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.badge,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1E26),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.gaegu(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E1E26),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.patrickHand(
                            fontSize: 19,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots & Next Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFFFFC72C)
                              : Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _items.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC72C),
                      foregroundColor: const Color(0xFF1E1E26),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _items.length - 1 ? "Let's Doodle! 🎨" : "Next",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_currentPage != _items.length - 1) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String badge;
  final String title;
  final String description;
  final String emoji;
  final Color color;

  OnboardingItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
  });
}
