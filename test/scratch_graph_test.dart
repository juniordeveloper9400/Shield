import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shield/module/refer/refer_earn_screen.dart';
import 'package:shield/module/refer/referral_level.dart';

const _out =
    r'D:\Temp\claude\d--zabnix-shield\5ced174b-741b-4426-9a19-6c5be857216b\scratchpad';

void main() {
  Future<void> shoot(WidgetTester tester, String name, int referrals) async {
    tester.view.physicalSize = const Size(411, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReferEarnScreen(
          progress: ReferralProgress(
            directReferrals: referrals,
            plansActivated: 2,
            sahakarMoney: 1000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finder = find.byKey(const ValueKey('standing-card'));
    debugPrint('$name height=${tester.getSize(finder).height}');
    await tester.runAsync(() async {
      final boundary =
          tester.firstRenderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary),
          );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$_out/$name.png');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes!.buffer.asUint8List());
      debugPrint('wrote ${f.absolute.path} ${f.existsSync()} ${f.lengthSync()}');
    });
  }

  testWidgets('level 1', (t) => shoot(t, 'graph_l1', 3));
  testWidgets('level 3', (t) => shoot(t, 'graph_l3', 12));
  testWidgets('nothing cleared', (t) => shoot(t, 'graph_l0', 0));
}
