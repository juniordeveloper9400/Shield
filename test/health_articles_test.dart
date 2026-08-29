import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/health_articles.dart';

void main() {
  Future<void> pumpStrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HealthArticlesSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the strip lists every article by title', (tester) async {
    await pumpStrip(tester);

    expect(find.text('Health Articles'), findsOneWidget);
    expect(
      find.text('How Pain Relief Medications Affect Liver and Kidney Health'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a card opens the full article', (tester) async {
    await pumpStrip(tester);

    await tester.tap(
      find.text('How Pain Relief Medications Affect Liver and Kidney Health'),
    );
    await tester.pumpAndSettle();

    final HealthArticle first = HealthArticlesSection.articles.first;

    expect(find.byType(HealthArticleScreen), findsOneWidget);
    // Header keeps the section name; the hero carries the cover line.
    expect(find.text('Health Articles'), findsOneWidget);
    expect(find.text(first.heroKicker), findsOneWidget);
    // Byline, category tags, and the contents list are all present.
    expect(
      find.textContaining('Amatul Ameen', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Disease Management'), findsOneWidget);
    expect(find.text('Health Conditions'), findsOneWidget);
    expect(find.text('Table of Contents'), findsOneWidget);
    expect(
      find.text('1. How paracetamol is processed by the liver'),
      findsOneWidget,
    );
  });

  testWidgets('the article back button returns to the strip', (tester) async {
    await pumpStrip(tester);

    await tester.tap(
      find.text('How Pain Relief Medications Affect Liver and Kidney Health'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HealthArticleScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(HealthArticleScreen), findsNothing);
    expect(find.text('Health Articles'), findsOneWidget);
  });
}
