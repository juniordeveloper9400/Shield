import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/brand_quote.dart';
import 'package:shield/module/home/category_section.dart';
import 'package:shield/module/home/home_footer.dart';
import 'package:shield/module/home/home_header.dart';
import 'package:shield/module/home/home_hero_banner.dart';
import 'package:shield/module/home/how_it_works.dart';
import 'package:shield/module/home/product_showcase.dart';
import 'package:shield/module/home/prescription_card.dart';
import 'package:shield/theme/app_colors.dart';
import 'package:shield/module/home/refer_earn_card.dart';
import 'package:shield/module/home/customer_testimonials.dart';
import 'package:shield/screens/home_screen.dart';
import 'package:shield/widgets/social_glyphs.dart';

void main() {
  // A tall surface forces every home section to lay out in one pass, including
  // the ones a normal viewport would leave unbuilt. Any RenderFlex overflow or
  // missing asset surfaces as a test failure.
  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // HomeScreen is always hosted by AppShell's Scaffold in production, which
    // is what supplies the Material ancestor its InkWells need.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home renders every section without overflow', (tester) async {
    await pumpHome(tester, const Size(400, 7000));

    expect(find.byType(HomeHeroBanner), findsOneWidget);
    expect(find.text('Shop by categories'), findsOneWidget);
    expect(find.text('New Product Arrivals'), findsOneWidget);
    expect(find.text('Popular Items'), findsOneWidget);
    expect(find.text("Deals You'll Love"), findsOneWidget);
    expect(find.text('What our customers have to say'), findsOneWidget);
  });

  testWidgets('review avatars and product cards are laid out', (tester) async {
    await pumpHome(tester, const Size(400, 7000));

    expect(find.text('Jai'), findsOneWidget);
    expect(find.text('SHIELD Immunity Plus'), findsOneWidget);
    expect(find.text('ADD'), findsWidgets);
  });

  testWidgets('narrow viewport still lays out product cards', (tester) async {
    await pumpHome(tester, const Size(320, 7000));

    expect(find.text('New Product Arrivals'), findsOneWidget);
    expect(find.byType(ProductShowcase), findsNWidgets(6));
  });

  testWidgets('exactly one cart icon exists, beside the wallet', (
    tester,
  ) async {
    const width = 400.0;
    await pumpHome(tester, const Size(width, 1200));

    // Still only one on the whole screen.
    final cart = find.byIcon(Icons.shopping_cart_outlined);
    expect(cart, findsOneWidget);

    // The cart is drawn by the collapsing chrome rather than by the header, so
    // that it can hold still while the header fades away beneath it. It must
    // still read as part of that row.
    final wallet = find.descendant(
      of: find.byType(HomeHeader),
      matching: find.byIcon(Icons.account_balance_wallet_outlined),
    );
    expect(wallet, findsOneWidget);

    final cartCentre = tester.getCenter(cart);
    final walletCentre = tester.getCenter(wallet);

    // Immediately to the wallet's right, on the same row.
    expect(cartCentre.dx, greaterThan(walletCentre.dx));
    expect(cartCentre.dx - walletCentre.dx, lessThan(80));
    expect((cartCentre.dy - walletCentre.dy).abs(), lessThan(1.0));

    // Cart is the trailing action, so it sits at the right edge.
    expect(width - tester.getTopRight(cart).dx, lessThan(24));
  });

  testWidgets('the cart is not beside the search field', (tester) async {
    await pumpHome(tester, const Size(400, 1200));

    final searchCentre = tester.getCenter(find.byType(TextField)).dy;
    final cartCentre = tester
        .getCenter(find.byIcon(Icons.shopping_cart_outlined))
        .dy;

    expect(
      cartCentre,
      lessThan(searchCentre - 20),
      reason: 'the cart belongs on the header row, above the search',
    );
  });

  testWidgets('scrolling collapses the chrome to the search and the cart', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 900));

    expect(find.byType(SliverPersistentHeader), findsOneWidget);

    final cart = find.byIcon(Icons.shopping_cart_outlined);
    final cartBefore = tester.getCenter(cart);
    final searchBefore = tester.getCenter(find.byType(TextField)).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // The search field and the cart are the two survivors.
    expect(find.byType(TextField), findsOneWidget);
    expect(cart, findsOneWidget);

    // And the cart has not shifted by so much as a pixel.
    expect(tester.getCenter(cart), cartBefore);

    // The rest of the header has faded out...
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.byType(HomeHeader), matching: find.byType(Opacity))
          .first,
    );
    expect(opacity.opacity, 0);

    // ...and the search has risen to take its place.
    expect(tester.getCenter(find.byType(TextField)).dy, lessThan(searchBefore));

    // The collapsed bar keeps a gap above it rather than sitting flush against
    // the top edge.
    // The pinned sliver sits flush with the viewport's top, so that is where
    // the collapsed bar starts.
    final chromeTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(
      tester.getTopLeft(find.byType(TextField)).dy - chromeTop,
      greaterThanOrEqualTo(8.0),
    );
    expect(tester.getTopLeft(cart).dy - chromeTop, greaterThanOrEqualTo(8.0));
  });

  testWidgets('refer & earn card sits in the top section', (tester) async {
    await pumpHome(tester, const Size(400, 7000));

    final card = find.byType(ReferEarnCard);
    final search = find.byType(TextField);
    final prescription = find.byType(PrescriptionCard);
    expect(card, findsOneWidget);

    final cardTop = tester.getTopLeft(card).dy;
    final searchTop = tester.getTopLeft(search).dy;
    final prescriptionTop = tester.getTopLeft(prescription).dy;

    // Below the search field, with the prescription card immediately under it
    // — the promo banner that used to sit between them is gone.
    expect(cardTop, greaterThan(searchTop));
    expect(cardTop, lessThan(prescriptionTop));
  });

  testWidgets(
    'the prescription card follows refer & earn with nothing between',
    (tester) async {
      await pumpHome(tester, const Size(400, 7000));

      expect(find.text('Shop medicines\nthe right way'), findsNothing);

      final referBottom = tester.getBottomLeft(find.byType(ReferEarnCard)).dy;
      final prescriptionTop = tester
          .getTopLeft(find.byType(PrescriptionCard))
          .dy;

      // Only the block's own padding separates them.
      expect(prescriptionTop - referBottom, lessThan(40));
      expect(prescriptionTop, greaterThan(referBottom));

      expect(find.text('Upload your prescription here'), findsOneWidget);
    },
  );

  testWidgets('the showcase artwork is square and spans the card', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 7000));

    // Square assets need a square box: a shorter one limits them to its own
    // height and leaves a gutter down either side of the card.
    final art = find
        .descendant(
          of: find.byType(ProductShowcase).first,
          matching: find.byType(AspectRatio),
        )
        .first;

    final size = tester.getSize(art);
    expect(size.width, size.height);
    expect(
      size.width,
      greaterThan(140),
      reason: 'the card is 162 wide, less its border and padding',
    );
  });

  testWidgets('product thumbnails sit on a white background', (tester) async {
    await pumpHome(tester, const Size(400, 7000));

    const tints = [
      AppColors.pageTint,
      AppColors.greenTint,
      AppColors.creamTint,
      AppColors.offerTint,
      AppColors.bannerTop,
    ];

    // No product card may paint a tinted panel behind its thumbnail.
    final tinted = find.descendant(
      of: find.byType(ProductShowcase).first,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration && tints.contains(decoration.color);
      }),
    );
    expect(tinted, findsNothing);

    // And a white-backed thumbnail panel is present.
    final white = find.descendant(
      of: find.byType(ProductShowcase).first,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.white;
      }),
    );
    expect(white, findsWidgets);
  });

  testWidgets('the feed carries every requested bottom section', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 7000));

    for (final title in const [
      'Vitamins & Supplements',
      'Popular Items',
      'Diabetes Care',
      'Health Conditions',
      "Deals You'll Love",
      'New Product Arrivals',
      'Health Articles',
      'Ratings & Reviews',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('the ratings block shows a score and star breakdown', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 7000));

    expect(find.byType(CustomerTestimonials), findsOneWidget);
    expect(find.text(CustomerTestimonials.score), findsOneWidget);
    expect(find.textContaining('ratings'), findsWidgets);

    // One bar per star level, five down to one.
    expect(
      CustomerTestimonials.distribution,
      hasLength(5),
      reason: 'the breakdown must cover every star level',
    );
    for (final share in CustomerTestimonials.distribution) {
      expect(share, inInclusiveRange(0.0, 1.0));
    }
  });

  testWidgets('the header shows the mark alone, sized to the menu glyph', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 1200));

    // The wordmark beside the logo is gone.
    expect(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.text('SHIELD'),
      ),
      findsNothing,
    );

    final logo = find.descendant(
      of: find.byType(HomeHeader),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/logos/shield_logo.png',
      ),
    );
    expect(logo, findsOneWidget);

    final menu = find.byIcon(Icons.menu_rounded);
    expect(
      tester.getSize(logo).height,
      tester.getSize(menu).height,
      reason: 'the mark should match the menu glyph, not tower over it',
    );
  });

  testWidgets('the brand claim signs the feed off, above the footer', (
    tester,
  ) async {
    // Taller than the rest of these cases need: the sign-off and the footer
    // are the last two blocks, and a sliver list does not build what is far
    // below the viewport.
    await pumpHome(tester, const Size(400, 8000));

    expect(find.text(BrandQuote.quote), findsOneWidget);

    final howItWorks = tester.getTopLeft(find.byType(HowItWorksSection)).dy;
    final quote = tester.getTopLeft(find.byType(BrandQuote)).dy;
    final footer = tester.getTopLeft(find.byType(HomeFooter)).dy;
    final categories = tester.getTopLeft(find.byType(CategorySection)).dy;

    expect(
      quote,
      greaterThan(categories),
      reason: 'it closes the feed rather than interrupting it',
    );
    expect(quote, greaterThan(howItWorks));
    expect(quote, lessThan(footer));
  });

  testWidgets('the sign-off carries the three social discs', (tester) async {
    await pumpHome(tester, const Size(400, 8000));

    final discs = find.descendant(
      of: find.byType(BrandQuote),
      matching: find.byType(SocialIcon),
    );
    expect(discs, findsNWidgets(SocialNetwork.values.length));

    // Facebook, YouTube and Instagram, in that order.
    expect(
      tester.widgetList<SocialIcon>(discs).map((disc) => disc.network),
      SocialNetwork.values,
    );
  });

  testWidgets('the footer does not repeat the social links', (tester) async {
    await pumpHome(tester, const Size(400, 8000));

    for (final network in SocialNetwork.values) {
      expect(
        find.descendant(
          of: find.byType(HomeFooter),
          matching: find.text(network.label),
        ),
        findsNothing,
        reason: '${network.label} belongs to the sign-off above the footer',
      );
    }
    // The footer keeps everything else it had.
    expect(
      find.descendant(
        of: find.byType(HomeFooter),
        matching: find.text('Need a hand?'),
      ),
      findsOneWidget,
    );
  });
}
