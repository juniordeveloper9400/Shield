import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/customer_reviews.dart';
import 'package:shield/module/home/home_footer.dart';
import 'package:shield/module/home/how_it_works.dart';
import 'package:shield/module/home/savings_card.dart';
import 'package:shield/module/home/why_shield.dart';
import 'package:shield/screens/home_screen.dart';

void main() {
  // Tall enough to lay the whole feed out in one pass, so a RenderFlex
  // overflow anywhere in the new blocks fails the test.
  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAlone(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('why shop with SHIELD', () {
    testWidgets('lists all four promises', (tester) async {
      await pumpAlone(tester, const WhyShieldSection(), const Size(400, 1400));

      expect(find.text('Why shop with SHIELD'), findsOneWidget);
      expect(find.text('100% genuine medicines'), findsOneWidget);
      expect(find.text('Save up to 51%'), findsOneWidget);
      expect(find.text('Free delivery over ₹500'), findsOneWidget);
      expect(find.text('Checked by pharmacists'), findsOneWidget);
    });

    testWidgets('survives a 320px viewport', (tester) async {
      await pumpAlone(tester, const WhyShieldSection(), const Size(320, 1400));

      expect(find.text('Checked by pharmacists'), findsOneWidget);
    });
  });

  group('how SHIELD works', () {
    testWidgets('numbers the three steps in order', (tester) async {
      await pumpAlone(tester, const HowItWorksSection(), const Size(400, 1400));

      expect(find.text('How SHIELD works'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      final search = tester.getTopLeft(find.text('Search or upload')).dy;
      final check = tester.getTopLeft(find.text('A pharmacist checks it')).dy;
      final deliver = tester.getTopLeft(find.text('Delivered to your door')).dy;

      expect(search, lessThan(check));
      expect(check, lessThan(deliver));
    });

    testWidgets('the rail joins every step but the last', (tester) async {
      await pumpAlone(tester, const HowItWorksSection(), const Size(400, 1400));

      // One connector between step 1 and 2, one between 2 and 3, none after.
      final rails = find.descendant(
        of: find.byType(HowItWorksSection),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 2,
        ),
      );
      expect(rails, findsNWidgets(2));
    });
  });

  group('footer', () {
    testWidgets('carries the contact rows, the links and the legal line', (
      tester,
    ) async {
      await pumpAlone(tester, const HomeFooter(), const Size(400, 1400));

      expect(find.text('Talk to a pharmacist'), findsOneWidget);
      expect(find.text('Chat with us'), findsOneWidget);
      expect(find.text('Email us'), findsOneWidget);

      for (final link in HomeFooter.links) {
        expect(find.text(link), findsOneWidget);
      }

      expect(
        find.textContaining('dispensed only against a valid prescription'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a link with no destination says so rather than doing nothing',
      (tester) async {
        await pumpAlone(tester, const HomeFooter(), const Size(400, 1400));

        await tester.tap(find.text('Privacy policy'));
        await tester.pumpAndSettle();

        expect(find.text('Privacy policy is coming soon'), findsOneWidget);
      },
    );

    testWidgets('a contact row does the same', (tester) async {
      await pumpAlone(tester, const HomeFooter(), const Size(400, 1400));

      await tester.tap(find.text('Chat with us'));
      await tester.pumpAndSettle();

      expect(find.text('Chat is coming soon'), findsOneWidget);
    });

    testWidgets('survives a 320px viewport', (tester) async {
      await pumpAlone(tester, const HomeFooter(), const Size(320, 1400));

      expect(find.text('FAQs'), findsOneWidget);
    });
  });

  group('in the home feed', () {
    testWidgets('the three blocks close the feed, in order', (tester) async {
      await pumpHome(tester, const Size(400, 8000));

      final reviews = find.byType(CustomerReviews);
      final why = find.byType(WhyShieldSection);
      final how = find.byType(HowItWorksSection);
      final footer = find.byType(HomeFooter);

      expect(why, findsOneWidget);
      expect(how, findsOneWidget);
      expect(footer, findsOneWidget);

      expect(
        tester.getTopLeft(reviews).dy,
        lessThan(tester.getTopLeft(why).dy),
      );
      expect(tester.getTopLeft(why).dy, lessThan(tester.getTopLeft(how).dy));
      expect(tester.getTopLeft(how).dy, lessThan(tester.getTopLeft(footer).dy));
    });

    testWidgets('the footer runs the full width', (tester) async {
      await pumpHome(tester, const Size(400, 8000));

      expect(tester.getSize(find.byType(HomeFooter)).width, 400);
    });
  });

  group('nothing sells the app to itself', () {
    testWidgets('no download or install copy survives anywhere in the feed', (
      tester,
    ) async {
      await pumpHome(tester, const Size(400, 8000));

      // The reader is already in the app, so none of this can be here.
      for (final copy in const [
        'Download App',
        'Download Now',
        'Install',
        'APP EXCLUSIVE OFFER',
        'TM28APP',
      ]) {
        expect(find.text(copy), findsNothing, reason: copy);
      }
      expect(find.textContaining('App Par'), findsNothing);
      expect(find.textContaining('Downloads'), findsNothing);
    });
  });
}
