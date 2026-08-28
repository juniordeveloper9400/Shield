import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/dietitian/dietitian_screen.dart';
import 'package:shield/module/home/home_hero_banner.dart';
import 'package:shield/module/health/health_section.dart';
import 'package:shield/module/labtest/package_card.dart';
import 'package:shield/module/labtest/top_packages_screen.dart';
import 'package:shield/screens/app_shell.dart';
import 'package:shield/widgets/bottom_nav.dart';
import 'package:shield/module/registration/register_bar.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  Future<void> openHealth(WidgetTester tester) async {
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
  }

  testWidgets('health landing shows collection, search, and packages', (
    tester,
  ) async {
    // Tall surface so the whole landing page lays out in one pass; the lower
    // sections would otherwise stay unbuilt in a phone-height viewport.
    await pumpShell(tester, size: const Size(400, 2400));
    await openHealth(tester);

    expect(find.text('Collect sample from'), findsOneWidget);
    expect(find.text('Select location'), findsOneWidget);
    expect(find.widgetWithText(TextField, ''), findsWidgets);
    expect(find.text('Top Packages'), findsWidgets);
    expect(find.text('Preventive Plus'), findsWidgets);
    expect(find.text('Book via'), findsNWidgets(2));
    expect(find.text('Flat 25% off on all tests'), findsOneWidget);
    expect(find.text('Top Profiles and Tests'), findsOneWidget);
  });

  testWidgets('the health section replaces the main bottom bar', (tester) async {
    await pumpShell(tester);

    // Main bar before entering.
    expect(find.byType(ShieldBottomNav), findsOneWidget);
    expect(find.byType(HealthBottomBar), findsNothing);

    await openHealth(tester);

    expect(find.byType(HealthBottomBar), findsOneWidget);
    expect(find.byType(ShieldBottomNav), findsNothing);
    // The registration strip belongs to the main chrome and goes with it.
    expect(find.byType(RegisterBar), findsNothing);
  });

  testWidgets('health bar switches to Top Packages and back', (tester) async {
    await pumpShell(tester);
    await openHealth(tester);

    // Offstage inside the IndexedStack until its sub-tab is selected.
    expect(find.byType(TopPackagesScreen), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Top Packages'),
      ),
    );
    await tester.pumpAndSettle();

    // The list page stacks every package vertically.
    expect(find.byType(TopPackagesScreen), findsOneWidget);
    expect(find.byType(PackageCard), findsWidgets);
    expect(find.text('Active Life'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Labs Tests'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collect sample from'), findsOneWidget);
  });

  testWidgets('the Home item leaves the section and restores the main bar', (
    tester,
  ) async {
    await pumpShell(tester);
    await openHealth(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HealthBottomBar), findsNothing);
    expect(find.byType(ShieldBottomNav), findsOneWidget);
    expect(find.byType(HomeHeroBanner), findsOneWidget);
  });

  testWidgets('re-entering the section starts back at the landing page', (
    tester,
  ) async {
    await pumpShell(tester);
    await openHealth(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Top Packages'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    await openHealth(tester);

    expect(find.text('Collect sample from'), findsOneWidget);
  });

  testWidgets('package card carries the full breakdown', (tester) async {
    await pumpShell(tester);
    await openHealth(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Top Packages'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('83 tests · 8 profiles'), findsOneWidget);
    expect(find.text('₹999'), findsOneWidget);
    expect(find.text('₹2,498'), findsOneWidget);
    expect(find.text('Saved ₹333 with coupon code'), findsOneWidget);
    expect(find.text('CBC'), findsOneWidget);
    expect(find.text('Thyroid Profile'), findsWidgets);

    // The second package rolls up its parent instead of relisting profiles.
    expect(find.text('Everything in Preventive Plus'), findsOneWidget);
    expect(find.text('+ 2 MORE TESTS · DIABETES'), findsOneWidget);
    expect(find.text('HbA1c'), findsOneWidget);
  });

  testWidgets('health section lays out on a narrow phone', (tester) async {
    await pumpShell(tester, size: const Size(320, 900));
    await openHealth(tester);

    expect(find.text('Collect sample from'), findsOneWidget);
    expect(find.byType(HealthBottomBar), findsOneWidget);
  });

  testWidgets('the dietitian shares the section instead of its own tab', (
    tester,
  ) async {
    await pumpShell(tester);

    // Merged away: the dietitian is no longer one of the five destinations.
    expect(
      find.descendant(
        of: find.byType(ShieldBottomNav),
        matching: find.text('Dietitian'),
      ),
      findsNothing,
    );

    await openHealth(tester);
    expect(find.byType(DietitianScreen), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Dietitian'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DietitianScreen), findsOneWidget);
    expect(find.text('Talk to a dietitian'), findsOneWidget);
    // Still inside the section, so its bar stays put.
    expect(find.byType(HealthBottomBar), findsOneWidget);

    // And back to the labs page without leaving the section.
    await tester.tap(
      find.descendant(
        of: find.byType(HealthBottomBar),
        matching: find.text('Labs Tests'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collect sample from'), findsOneWidget);
  });

  testWidgets('the section bar carries Home plus all three sub-tabs', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(320, 900));
    await openHealth(tester);

    for (final label in const [
      'Home',
      'Labs Tests',
      'Top Packages',
      'Dietitian',
    ]) {
      expect(
        find.descendant(
          of: find.byType(HealthBottomBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }
  });
}
