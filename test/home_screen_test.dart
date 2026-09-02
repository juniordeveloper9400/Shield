import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/cart/cart_badge.dart';
import 'package:shield/module/cart/cart_screen.dart';
import 'package:shield/module/home/brand_quote.dart';
import 'package:shield/module/home/category_section.dart';
import 'package:shield/module/home/customer_reviews.dart';
import 'package:shield/module/home/home_header.dart';
import 'package:shield/module/home/points_badge.dart';
import 'package:shield/module/refer/refer_earn_screen.dart';
import 'package:shield/module/registration/registration_service.dart';
import 'package:shield/module/rewards/rewards_screen.dart';
import 'package:shield/money.dart';
import 'package:shield/module/home/home_hero_banner.dart';
import 'package:shield/module/home/product_collection_screen.dart';
import 'package:shield/module/home/product_showcase.dart';
import 'package:shield/module/search/search_screen.dart';
import 'package:shield/module/home/prescription_card.dart';
import 'package:shield/theme/app_colors.dart';
import 'package:shield/module/home/refer_earn_card.dart';
import 'package:shield/module/home/customer_testimonials.dart';
import 'package:shield/screens/home_screen.dart';
import 'package:shield/widgets/social_glyphs.dart';

import 'support/fake_catalogue.dart';

void main() {
  // The home product rows read from CatalogueService, which has no database in
  // a test — seed it with the fixture catalogue so the rows have products.
  setUp(seedFakeCatalogue);
  tearDown(resetFakeCatalogue);

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

  /// How opaque a widget is drawn, read off the Opacity wrapping it.
  double opacityOf(WidgetTester tester, Finder finder) => tester
      .widget<Opacity>(
        find.ancestor(of: finder, matching: find.byType(Opacity)).first,
      )
      .opacity;

  /// The width the collapsing cart actually takes from the search field,
  /// which its Align shrinks to nothing while the header still carries one.
  double collapsedCartWidth(WidgetTester tester) => tester.getSize(
    find.ancestor(of: find.byKey(pinnedCartKey), matching: find.byType(Align)).first,
  ).width;

  testWidgets('home renders every section without overflow', (tester) async {
    await pumpHome(tester, const Size(400, 8000));

    expect(find.byType(HomeHeroBanner), findsOneWidget);
    expect(find.text('Shop by categories'), findsOneWidget);
    expect(find.text('Popular Items'), findsOneWidget);
    expect(find.text('Deals You Love'), findsOneWidget);
    expect(find.text('Wellness & Supplements'), findsOneWidget);
    expect(find.text('What our customers have to say'), findsOneWidget);
  });

  testWidgets('review avatars and product cards are laid out', (tester) async {
    await pumpHome(tester, const Size(400, 8000));

    expect(find.text(CustomerReviews.reviews.first.name), findsOneWidget);
    expect(find.text('SHIELD Immunity Plus'), findsWidgets);
    expect(find.text('ADD'), findsWidgets);
  });

  testWidgets('narrow viewport still lays out product cards', (tester) async {
    await pumpHome(tester, const Size(320, 8000));

    expect(find.text('Popular Items'), findsOneWidget);
    expect(find.text('Deals You Love'), findsOneWidget);
    expect(find.text('Wellness & Supplements'), findsOneWidget);
    expect(find.byType(ProductShowcase), findsNWidgets(3));
  });

  testWidgets('home shows the cart icon beside the wallet', (tester) async {
    await pumpHome(tester, const Size(400, 1200));

    final cart = find.descendant(
      of: find.byType(HomeHeader),
      matching: find.byType(CartBadge),
    );
    expect(cart, findsOneWidget);

    final wallet = find.descendant(
      of: find.byType(HomeHeader),
      matching: find.byIcon(Icons.account_balance_wallet_outlined),
    );
    expect(wallet, findsOneWidget);

    final cartCentre = tester.getCenter(cart);
    final walletCentre = tester.getCenter(wallet);

    expect(cartCentre.dx, lessThan(walletCentre.dx));
    expect((cartCentre.dy - walletCentre.dy).abs(), lessThan(1.0));
  });

  group('the points coin', () {
    setUp(RegistrationService.instance.reset);
    tearDown(RegistrationService.instance.reset);

    testWidgets('rides in the header beside the wallet', (tester) async {
      await pumpHome(tester, const Size(400, 1200));

      final coin = find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byType(PointsBadge),
      );
      expect(coin, findsOneWidget);

      // The opening balance, printed where a member can see it without
      // opening the menu — which is the whole reason it is here.
      expect(
        find.text(formatRupees(RegistrationService.openingPoints)),
        findsOneWidget,
      );

      // On the same row as the wallet, with the cart between them: the three
      // figures the account carries, read in one glance.
      final wallet = find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byIcon(Icons.account_balance_wallet_outlined),
      );
      final cart = find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byType(CartBadge),
      );
      final coinCentre = tester.getCenter(coin);
      final cartCentre = tester.getCenter(cart);
      final walletCentre = tester.getCenter(wallet);

      expect(coinCentre.dx, lessThan(cartCentre.dx));
      expect(cartCentre.dx, lessThan(walletCentre.dx));
      expect((coinCentre.dy - walletCentre.dy).abs(), lessThan(1.0));
    });

    testWidgets('lays out on the narrowest phone', (tester) async {
      await pumpHome(tester, const Size(320, 1200));

      expect(find.byType(PointsBadge), findsOneWidget);
      // The coin gives way before the wallet does, so both are still there.
      expect(
        find.descendant(
          of: find.byType(HomeHeader),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the balance rather than printing it once', (
      tester,
    ) async {
      await pumpHome(tester, const Size(400, 1200));

      const opening = RegistrationService.openingPoints;
      expect(find.text(formatRupees(opening)), findsOneWidget);

      // Registering credits the reward, and the coin has to be seen to move.
      RegistrationService.instance.save(
        Registration(
          name: 'Asha Nair',
          phone: '9000012345',
          email: 'asha@example.com',
          gender: Gender.female,
          dob: DateTime(1994, 9, 4),
          address: '12/A Palm Grove',
          place: 'Perinthalmanna',
          pincode: '679322',
          state: 'Kerala',
          storeId: 'SHD-MEL',
        ),
      );
      await tester.pump();

      expect(find.text(formatRupees(opening)), findsNothing);
      expect(
        find.text(formatRupees(opening + RegistrationService.rewardPoints)),
        findsOneWidget,
      );
    });

    testWidgets('opens the rewards screen', (tester) async {
      await pumpHome(tester, const Size(400, 1200));

      await tester.tap(find.byType(PointsBadge));
      await tester.pumpAndSettle();

      expect(find.byType(RewardsScreen), findsOneWidget);
      expect(find.text('GET INSTANT COINS'), findsOneWidget);
    });

    testWidgets('rewards screen hands off to the refer journey', (tester) async {
      await pumpHome(tester, const Size(400, 1600));

      await tester.tap(find.byType(PointsBadge));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refer & Earn'));
      await tester.pumpAndSettle();

      expect(find.byType(ReferEarnScreen), findsOneWidget);
    });
  });

  testWidgets('expanded, the cart is in the header row, not beside the search', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 1200));

    expect(find.byType(TextField), findsOneWidget);

    // The header's own cart sits a row above the search field.
    final headerCart = find.descendant(
      of: find.byType(HomeHeader),
      matching: find.byType(CartBadge),
    );
    expect(headerCart, findsOneWidget);
    expect(
      tester.getBottomLeft(headerCart).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );

    // The pinned one is in the tree but drawn away to nothing, so the search
    // field still runs the full width between the screen's margins.
    expect(opacityOf(tester, find.byKey(pinnedCartKey)), 0);
    expect(collapsedCartWidth(tester), 0);
    expect(tester.getSize(find.byType(TextField)).width, 400 - 16 * 2);
  });

  testWidgets('scrolled, a cart rides the search field', (tester) async {
    await pumpHome(tester, const Size(400, 900));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    final cart = find.byKey(pinnedCartKey);
    final search = find.byType(TextField);

    // Fully drawn now that the header carrying the other one has gone.
    expect(opacityOf(tester, cart), 1);
    expect(collapsedCartWidth(tester), greaterThan(0));

    // Beside the search field rather than above it, and level with it.
    expect(
      tester.getTopLeft(cart).dx,
      greaterThan(tester.getTopRight(search).dx - 1),
    );
    expect(
      tester.getCenter(cart).dy,
      closeTo(tester.getCenter(search).dy, 0.5),
    );

    // Right up against the screen's margin, so the pair reads as one bar.
    expect(tester.getTopRight(cart).dx, 400 - 16);

    // And it opens the products basket.
    await tester.tap(cart);
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
  });

  testWidgets('scrolling collapses the chrome to the search field', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 900));

    expect(find.byType(SliverPersistentHeader), findsOneWidget);

    final searchBefore = tester.getCenter(find.byType(TextField)).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // The search field is the survivor, and the pinned cart rides with it.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(pinnedCartKey), findsOneWidget);

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

  testWidgets('"View all" opens the showcase\'s own products in a grid', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 9000));

    // The "View all" belonging to "Deals You Love".
    final viewAll = find.descendant(
      of: find.ancestor(
        of: find.text('Deals You Love'),
        matching: find.byType(ProductShowcase),
      ),
      matching: find.text('View all'),
    );
    await tester.ensureVisible(viewAll);
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    // Lands on the collection screen carrying that row's title and every one
    // of its products — including ones further along than the feed showed.
    expect(find.byType(ProductCollectionScreen), findsOneWidget);
    expect(find.text('Deals You Love'), findsOneWidget);
    expect(
      find.text('${ProductCatalogue.dealsYouLove.length} items'),
      findsOneWidget,
    );
    expect(find.text('Soft Soles Foot Cream'), findsOneWidget);
  });

  group('the "View all" collection screen', () {
    Future<void> openDealsCollection(WidgetTester tester) async {
      await pumpHome(tester, const Size(400, 9000));
      final viewAll = find.descendant(
        of: find.ancestor(
          of: find.text('Deals You Love'),
          matching: find.byType(ProductShowcase),
        ),
        matching: find.text('View all'),
      );
      await tester.ensureVisible(viewAll);
      await tester.tap(viewAll);
      await tester.pumpAndSettle();
    }

    testWidgets('the app-bar magnifier opens the app-wide product search', (
      tester,
    ) async {
      await openDealsCollection(tester);

      // Matches the category listing screen: search is a magnifier in the app
      // bar, not an inline box on this screen.
      expect(find.widgetWithText(TextField, 'Search these products'), findsNothing);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('the filter sheet orders the grid by price, low to high', (
      tester,
    ) async {
      await openDealsCollection(tester);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price — low to high'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Soft Soles (₹165) is the cheapest in the row and now leads it; Protein
      // Powder (₹1,999) is the dearest and sits below.
      final cheapest = tester.getTopLeft(find.text('Soft Soles Foot Cream')).dy;
      final dearest = tester.getTopLeft(find.text('Protein Powder Chocolate')).dy;
      expect(cheapest, lessThan(dearest));

      // The pill now carries its active count, the same as the category
      // listing screen's.
      expect(find.text('Filter · 1'), findsOneWidget);
    });

    testWidgets('the filter sheet is the two-pane rail the listing screen uses', (
      tester,
    ) async {
      await openDealsCollection(tester);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      // A "Filters" header, a left rail of facets, and a Clear / Apply foot.
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Offers'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      // The Offers rail swaps the right pane to its own options.
      await tester.tap(find.text('Offers'));
      await tester.pumpAndSettle();
      expect(find.text('On offer only'), findsOneWidget);
      await tester.tap(find.text('On offer only'));
      await tester.pumpAndSettle();

      // That rail tab now shows a count of one.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Offers'),
            matching: find.byType(InkWell),
          ),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('the feed carries every requested bottom section', (
    tester,
  ) async {
    await pumpHome(tester, const Size(400, 8000));

    for (final title in const [
      'Popular Items',
      'Deals You Love',
      'Wellness & Supplements',
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

  testWidgets('the brand claim signs the feed off', (tester) async {
    await pumpHome(tester, const Size(400, 8000));

    expect(find.text(BrandQuote.quote), findsOneWidget);

    final quote = tester.getTopLeft(find.byType(BrandQuote)).dy;
    final categories = tester.getTopLeft(find.byType(CategorySection)).dy;

    // It is the last thing in the feed now: "Why shop with SHIELD", "How
    // SHIELD works" and the footer used to sit under it and no longer do.
    expect(
      quote,
      greaterThan(categories),
      reason: 'it closes the feed rather than interrupting it',
    );
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
}
