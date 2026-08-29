import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/home/customer_reviews.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    for (final review in CustomerReviews.reviews.take(3)) {
      expect(find.text(review.name), findsOneWidget, reason: review.name);
    }
  });

  testWidgets('tapping a customer card opens the video story player modal', (
    tester,
  ) async {
    await pumpReviews(tester);

    await tester.tap(find.text(CustomerReviews.reviews.first.name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomerStoryPlayerModal), findsOneWidget);
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

    await tester.tap(find.text(CustomerReviews.reviews.first.name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scoped to the player, which is the only place a transport control
    // belongs — the reel behind it carries none.
    Finder inPlayer(IconData icon) => find.descendant(
      of: find.byType(CustomerStoryPlayerModal),
      matching: find.byIcon(icon),
    );

    // Initially playing -> shows pause icon
    expect(inPlayer(Icons.pause_rounded), findsOneWidget);

    // Tap to pause -> shows play icon
    await tester.tap(inPlayer(Icons.pause_rounded));
    await tester.pump();
    expect(inPlayer(Icons.play_arrow_rounded), findsOneWidget);

    // Tap to resume -> shows pause icon again
    await tester.tap(inPlayer(Icons.play_arrow_rounded));
    await tester.pump();
    expect(inPlayer(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('mute toggles in the video story player', (tester) async {
    await pumpReviews(tester);

    await tester.tap(find.text(CustomerReviews.reviews.first.name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  test('every entry is a clip of its own', () {
    final reviews = CustomerReviews.reviews;
    expect(reviews, isNotEmpty);

    // No clip used twice, and no two entries sharing an id or a label.
    expect(reviews.map((r) => r.video).toSet(), hasLength(reviews.length));
    expect(reviews.map((r) => r.id).toSet(), hasLength(reviews.length));
    expect(reviews.map((r) => r.name).toSet(), hasLength(reviews.length));
  });

  test('every clip path is one a URI can survive', () {
    // Both batches of clips arrived with spaces in their filenames and both
    // times the reel showed placeholders. An asset path is a URI, so this is
    // pinned rather than left to be rediscovered a third time.
    for (final review in CustomerReviews.reviews) {
      expect(
        review.video,
        matches(RegExp(r'^assets/reviews/[a-z0-9_]+\.mp4$')),
        reason: review.video,
      );
    }
  });

  test('every clip named is a clip that is bundled', () async {
    // The reel pointed at eleven files that had been deleted and replaced,
    // which is why it showed nothing. Loading each one proves the paths and
    // the pubspec agree with what is on disk.
    for (final review in CustomerReviews.reviews) {
      final data = await rootBundle.load(review.video);
      final bytes = data.buffer.asUint8List();
      expect(bytes.length, greaterThan(1000), reason: review.video);
      expect(
        String.fromCharCodes(bytes.sublist(4, 8)),
        'ftyp',
        reason: '${review.video} is not an MP4',
      );
    }
  });

  testWidgets('the reel is stills, with nothing to press on them', (
    tester,
  ) async {
    await pumpReviews(tester);

    // The cards are photographs: one frame out of the clip, paused. Nothing
    // plays until the story player is opened, so nothing on a card offers to
    // play it — no play badge, no transport of any kind.
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

    // The whole card is the target instead, and it opens the player.
    await tester.tap(find.text(CustomerReviews.reviews.first.name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomerStoryPlayerModal), findsOneWidget);
  });

  test('every clip that ships is a clip the reel plays', () async {
    // Clips arrive as a folder drop. Anything bundled under assets/reviews is
    // meant to be seen, so a file that nobody added to the list is a clip
    // that silently never plays — this is what catches that.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest
        .listAssets()
        .where((asset) => asset.startsWith('assets/reviews/'))
        .toSet();

    expect(bundled, isNotEmpty);
    expect(
      CustomerReviews.reviews.map((review) => review.video).toSet(),
      bundled,
      reason: 'the reel and the folder have to hold the same clips',
    );
  });

  test('every clip carries its index up front', () async {
    // An MP4 keeps its index in a `moov` box and its frames in `mdat`. Seven
    // of these eight shipped with `moov` written after `mdat`, which means a
    // player has to read the whole file before it can show one frame — the
    // wait that used to sit behind the story player. `ffmpeg -movflags
    // +faststart` moves it to the front, and any clip added later has to be
    // remuxed the same way, so it is pinned here rather than left to be
    // rediscovered.
    for (final review in CustomerReviews.reviews) {
      final bytes = (await rootBundle.load(review.video)).buffer.asUint8List();

      final boxes = <String>[];
      var offset = 0;
      while (offset + 8 <= bytes.length && boxes.length < 8) {
        final size = ByteData.sublistView(
          bytes,
          offset,
          offset + 4,
        ).getUint32(0);
        boxes.add(String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)));
        // 1 means a 64-bit length follows and 0 means "to the end"; neither
        // shape is expected here, and walking past one would read garbage.
        if (size < 8) {
          break;
        }
        offset += size;
      }

      expect(boxes, contains('moov'), reason: review.video);
      expect(
        boxes.indexOf('moov'),
        lessThan(boxes.indexOf('mdat')),
        reason: '${review.video} needs -movflags +faststart: $boxes',
      );
    }
  });

  testWidgets('nothing stands in front of a clip while it loads', (
    tester,
  ) async {
    // No platform decodes video here, so every surface in this suite is
    // sitting on its placeholder — which is exactly the state this is about.
    await pumpReviews(tester);

    // A camcorder mark that shows for a moment and then vanishes announces
    // the wait instead of covering it.
    expect(find.byIcon(Icons.videocam_rounded), findsNothing);

    await tester.tap(find.text(CustomerReviews.reviews.first.name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CustomerStoryPlayerModal), findsOneWidget);
    expect(
      find.byIcon(Icons.videocam_rounded),
      findsNothing,
      reason: 'the player opens on the clip, not on an icon of one',
    );
  });

  testWidgets('a clip that will not play leaves the card readable', (
    tester,
  ) async {
    // No platform decodes video under flutter_test, so every clip in this
    // suite fails to initialise. The reel still has to render, name its
    // customers and open its player — which is what the tests above just
    // did, and what a broken asset on a real device would fall back to.
    await pumpReviews(tester);

    expect(find.byType(CustomerReviews), findsOneWidget);
    expect(find.text(CustomerReviews.reviews.first.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
