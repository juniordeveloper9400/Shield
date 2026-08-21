import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/customer_reviews.dart';

void main() {
  Future<void> pumpReviews(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CustomerReviews())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders customer video review section with cards', (
    tester,
  ) async {
    await pumpReviews(tester);

    expect(find.text('What our customers have to say'), findsOneWidget);
    expect(find.text('Jai'), findsOneWidget);
    expect(find.text('Srishti'), findsOneWidget);
    expect(find.text('Anil'), findsOneWidget);
  });

  testWidgets('tapping a customer card opens the video story player modal', (
    tester,
  ) async {
    await pumpReviews(tester);

    // Tap Jai's review card
    await tester.tap(find.text('Jai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomerStoryPlayerModal), findsOneWidget);
    expect(find.textContaining('basically main belong'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Tapping close dismisses player
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerStoryPlayerModal), findsNothing);
  });

  testWidgets('play pause button toggles in the video story player', (
    tester,
  ) async {
    await pumpReviews(tester);

    await tester.tap(find.text('Jai'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Initially playing -> shows pause icon
    final pauseBtn = find.byIcon(Icons.pause_rounded);
    expect(pauseBtn, findsOneWidget);

    // Tap to pause -> shows play icon
    await tester.tap(pauseBtn);
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    // Tap to resume -> shows pause icon again
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });
}
