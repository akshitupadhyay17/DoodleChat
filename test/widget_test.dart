import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doodle_chat/main.dart';
import 'package:doodle_chat/screens/splash_screen.dart';
import 'package:doodle_chat/screens/onboarding_screen.dart';
import 'package:doodle_chat/screens/auth_screen.dart';
import 'package:doodle_chat/screens/home_screen.dart';
import 'package:doodle_chat/screens/profile_screen.dart';

void main() {
  testWidgets('DoodleChatApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DoodleChatApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.byType(DoodleChatApp), findsOneWidget);
  });

  final screenSizes = [
    const Size(320, 568),  // iPhone SE 1st gen
    const Size(375, 667),  // iPhone SE 2nd/3rd gen
    const Size(390, 844),  // iPhone 14 / 15 / 16
    const Size(430, 932),  // iPhone 16 Pro Max
    const Size(768, 1024), // iPad / Tablet
  ];

  for (final size in screenSizes) {
    testWidgets('OnboardingScreen renders without overflow on ${size.width}x${size.height}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SplashScreen renders without overflow on ${size.width}x${size.height}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AuthScreen renders without overflow on ${size.width}x${size.height}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeScreen renders without overflow on ${size.width}x${size.height}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? caughtDetails;
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        oldOnError?.call(details);
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldOnError;
      if (caughtDetails != null) {
        print('=== HOME SCREEN ERROR DETAILS ===');
        print(caughtDetails!.toString());
        print('=================================');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen renders without overflow on ${size.width}x${size.height}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
