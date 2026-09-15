import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:shield/module/home/customer_reviews.dart';
import 'package:shield/module/home/customer_reviews_service.dart';
import 'package:shield/module/home/review_video_player_screen.dart';

/// A no-op `webview_flutter` platform, registered below so
/// `YoutubePlayerController`/`YoutubePlayer` can build under `flutter_test`
/// — which has no real WebView — instead of throwing on
/// `WebViewPlatform.instance == null`.
class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);
}

/// Every method a no-op success rather than the base class's default
/// `UnimplementedError`, since `YoutubePlayerController` calls a handful of
/// these synchronously while it sets itself up.
class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> loadFile(String absoluteFilePath) async {}
  @override
  Future<void> loadFileWithParams(LoadFileParams params) async {}
  @override
  Future<void> loadFlutterAsset(String key) async {}
  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
  @override
  Future<String?> currentUrl() async => null;
  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<bool> canGoForward() async => false;
  @override
  Future<void> goBack() async {}
  @override
  Future<void> goForward() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<void> clearCache() async {}
  @override
  Future<void> clearLocalStorage() async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    covariant PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> runJavaScript(String javaScript) async {}
  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => '';
  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    // Real YouTube posts a `{"playerId": ..., "Ready": ...}` message back
    // over this channel once the iframe loads, which is what lets
    // `YoutubePlayerController` complete its internal "ready" wait. With no
    // real page here to post it, echo one back immediately — otherwise that
    // wait times out after 30 (fake-clock) seconds, via a `Timer` that's
    // still pending — and fails `flutter_test`'s teardown check — for every
    // test in this file, not just the one that triggered it.
    javaScriptChannelParams.onMessageReceived(
      JavaScriptMessage(
        message: jsonEncode({'playerId': javaScriptChannelParams.name, 'Ready': true}),
      ),
    );
  }
  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {}
  @override
  Future<String?> getTitle() async => null;
  @override
  Future<void> scrollTo(int x, int y) async {}
  @override
  Future<void> scrollBy(int x, int y) async {}
  @override
  Future<void> setVerticalScrollBarEnabled(bool enabled) async {}
  @override
  Future<void> setHorizontalScrollBarEnabled(bool enabled) async {}
  @override
  Future<void> enableZoom(bool enabled) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  @override
  Future<void> setUserAgent(String? userAgent) async {}
  @override
  Future<String?> getUserAgent() async => null;
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}
  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}
  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}
  @override
  Future<void> setOnHttpAuthRequest(
    HttpAuthRequestCallback onHttpAuthRequest,
  ) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WebViewPlatform.instance = _FakeWebViewPlatform();

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

  group('YouTube links', () {
    test('youtubeId reads every URL shape the admin might paste', () {
      const cases = {
        'https://www.youtube.com/watch?v=aqz-KE-bpKQ': 'aqz-KE-bpKQ',
        'https://youtube.com/watch?v=aqz-KE-bpKQ&t=42s': 'aqz-KE-bpKQ',
        'https://m.youtube.com/watch?v=aqz-KE-bpKQ': 'aqz-KE-bpKQ',
        'https://youtu.be/aqz-KE-bpKQ': 'aqz-KE-bpKQ',
        'https://youtu.be/aqz-KE-bpKQ?t=5': 'aqz-KE-bpKQ',
        'https://www.youtube.com/embed/aqz-KE-bpKQ': 'aqz-KE-bpKQ',
        'https://www.youtube.com/shorts/aqz-KE-bpKQ': 'aqz-KE-bpKQ',
      };
      cases.forEach((url, id) {
        final review = CustomerReviewItem(id: 't', name: 't', video: url);
        expect(review.youtubeId, id, reason: url);
      });
    });

    test('youtubeId is null for a bundled asset or a direct hosted file', () {
      const notYoutube = [
        'assets/reviews/melattur_store.mp4',
        'https://cdn.example.com/reviews/clip.mp4',
        'https://firebasestorage.googleapis.com/v0/b/x/o/clip.mp4',
      ];
      for (final video in notYoutube) {
        final review = CustomerReviewItem(id: 't', name: 't', video: video);
        expect(review.youtubeId, isNull, reason: video);
      }
    });

    test("displayThumbnail falls back to YouTube's own poster", () {
      const withCustom = CustomerReviewItem(
        id: 't',
        name: 't',
        video: 'https://youtu.be/aqz-KE-bpKQ',
        thumbnail: 'https://example.com/custom.jpg',
      );
      expect(withCustom.displayThumbnail, 'https://example.com/custom.jpg');

      const withoutCustom = CustomerReviewItem(
        id: 't',
        name: 't',
        video: 'https://youtu.be/aqz-KE-bpKQ',
      );
      expect(
        withoutCustom.displayThumbnail,
        'https://img.youtube.com/vi/aqz-KE-bpKQ/hqdefault.jpg',
      );

      const bundled = CustomerReviewItem(
        id: 't',
        name: 't',
        video: 'assets/reviews/melattur_store.mp4',
      );
      expect(bundled.displayThumbnail, isNull);
    });

    testWidgets('tapping a YouTube card opens the dedicated player screen', (
      tester,
    ) async {
      const youtubeReview = CustomerReviewItem(
        id: 'yt',
        name: 'A YouTube reviewer',
        video: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        subtitle: 'Loved the service',
      );
      const bundledReview = CustomerReviewItem(
        id: 'bundled',
        name: 'A bundled reviewer',
        video: 'assets/reviews/melattur_store.mp4',
      );
      CustomerReviewsService.instance.debugSeed([
        youtubeReview,
        bundledReview,
      ]);
      addTearDown(CustomerReviewsService.instance.debugReset);

      await pumpReviews(tester);

      await tester.tap(find.text(youtubeReview.name));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewVideoPlayerScreen), findsOneWidget);
      expect(find.byType(CustomerStoryPlayerModal), findsNothing);
      final screen = tester.widget<ReviewVideoPlayerScreen>(
        find.byType(ReviewVideoPlayerScreen),
      );
      expect(screen.videoId, 'aqz-KE-bpKQ');
      expect(screen.title, youtubeReview.name);
      expect(screen.description, youtubeReview.subtitle);

      // Backing out and tapping the other card still opens the swipeable
      // story player — only a YouTube link is routed away from it.
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Not pumpAndSettle here: the fallback progress animation runs for the
      // review's full duration (8s default), and settling would sweep clean
      // through it — finishing and popping the story before the assertion
      // below runs, the same reason every other test that opens this modal
      // uses a fixed pump instead.
      await tester.tap(find.text(bundledReview.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CustomerStoryPlayerModal), findsOneWidget);
      expect(find.byType(ReviewVideoPlayerScreen), findsNothing);
    });

    testWidgets(
      "a YouTube card's thumbnail is YouTube's own poster, with no admin thumbnail",
      (tester) async {
        const youtubeReview = CustomerReviewItem(
          id: 'yt',
          name: 'A YouTube reviewer',
          video: 'https://youtu.be/aqz-KE-bpKQ',
        );
        CustomerReviewsService.instance.debugSeed([youtubeReview]);
        addTearDown(CustomerReviewsService.instance.debugReset);

        await pumpReviews(tester);

        final image = tester.widget<Image>(find.byType(Image).first);
        final provider = image.image as NetworkImage;
        expect(
          provider.url,
          'https://img.youtube.com/vi/aqz-KE-bpKQ/hqdefault.jpg',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
