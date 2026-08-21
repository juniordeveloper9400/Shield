import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/home_hero_banner.dart';
import 'package:shield/module/labtest/lab_section.dart';
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

  Future<void> openLab(WidgetTester tester) async {
    await tester.tap(find.text('Lab'));
    await tester.pumpAndSettle();
  }

  testWidgets('lab landing shows collection, search, and packages', (
    tester,
  ) async {
    // Tall surface so the whole landing page lays out in one pass; the lower
    // sections would otherwise stay unbuilt in a phone-height viewport.
    await pumpShell(tester, size: const Size(400, 2400));
    await openLab(tester);

    expect(find.text('Collect sample from'), findsOneWidget);
    expect(find.text('Select location'), findsOneWidget);
    expect(find.widgetWithText(TextField, ''), findsWidgets);
    expect(find.text('Top Packages'), findsWidgets);
    expect(find.text('Preventive Plus'), findsWidgets);
    expect(find.text('Book via'), findsNWidgets(2));
    expect(find.text('Flat 25% off on all tests'), findsOneWidget);
    expect(find.text('Top Profiles and Tests'), findsOneWidget);
  });

  testWidgets('the lab section replaces the main bottom bar', (tester) async {
    await pumpShell(tester);

    // Main bar before entering.
    expect(find.byType(ShieldBottomNav), findsOneWidget);
    expect(find.byType(LabBottomBar), findsNothing);

    await openLab(tester);

    expect(find.byType(LabBottomBar), findsOneWidget);
    expect(find.byType(ShieldBottomNav), findsNothing);
    // The registration strip belongs to the main chrome and goes with it.
    expect(find.byType(RegisterBar), findsNothing);
  });

  testWidgets('lab bar switches to Top Packages and back', (tester) async {
    await pumpShell(tester);
    await openLab(tester);

    // Offstage inside the IndexedStack until its sub-tab is selected.
    expect(find.byType(TopPackagesScreen), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(LabBottomBar),
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
        of: find.byType(LabBottomBar),
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
    await openLab(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(LabBottomBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LabBottomBar), findsNothing);
    expect(find.byType(ShieldBottomNav), findsOneWidget);
    expect(find.byType(HomeHeroBanner), findsOneWidget);
  });

  testWidgets('re-entering the section starts back at the landing page', (
    tester,
  ) async {
    await pumpShell(tester);
    await openLab(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(LabBottomBar),
        matching: find.text('Top Packages'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(LabBottomBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    await openLab(tester);

    expect(find.text('Collect sample from'), findsOneWidget);
  });

  testWidgets('package card carries the full breakdown', (tester) async {
    await pumpShell(tester);
    await openLab(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(LabBottomBar),
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

  testWidgets('lab section lays out on a narrow phone', (tester) async {
    await pumpShell(tester, size: const Size(320, 900));
    await openLab(tester);

    expect(find.text('Collect sample from'), findsOneWidget);
    expect(find.byType(LabBottomBar), findsOneWidget);
  });
}
