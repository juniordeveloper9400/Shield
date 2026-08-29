import 'package:flutter/material.dart';

import 'privilege_screen.dart';

/// Takes the privilege cards out of their pocket, then opens the programme.
///
/// The home strip and the locked wallet offer the same three cards, so they
/// have to come out of the pocket the same way: a fan that is quicker or
/// springier on one screen than on the other reads as two different objects
/// rather than as one wallet seen twice. The timing lives here once, and both
/// screens build against the animation it hands them.
class PrivilegeCardsLaunch extends StatefulWidget {
  /// Built with the fan to drive [PrivilegeWallet] with, and the callback
  /// every control that offers the cards should fire.
  final Widget Function(
    BuildContext context,
    Animation<double> fan,
    VoidCallback open,
  )
  builder;

  const PrivilegeCardsLaunch({super.key, required this.builder});

  /// Out slower than back in: cards spring out of a pocket and are pushed
  /// back into one.
  static const Duration fanOut = Duration(milliseconds: 420);
  static const Duration fanIn = Duration(milliseconds: 260);

  @override
  State<PrivilegeCardsLaunch> createState() => _PrivilegeCardsLaunchState();
}

class _PrivilegeCardsLaunchState extends State<PrivilegeCardsLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fan = AnimationController(
    vsync: this,
    duration: PrivilegeCardsLaunch.fanOut,
    reverseDuration: PrivilegeCardsLaunch.fanIn,
  );

  /// Out with a little overshoot, back in without.
  late final Animation<double> _curve = CurvedAnimation(
    parent: _fan,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    // A second tap while the cards are already on their way out would push the
    // programme twice, and the locked wallet offers three controls that all
    // land here. A tap while they are going back in is a change of mind, and
    // sends them out again from wherever they have got to.
    if (_fan.status == AnimationStatus.forward ||
        _fan.status == AnimationStatus.completed) {
      return;
    }

    // The cards come out first, then the programme opens behind them, and
    // they go back in the pocket when it closes.
    await _fan.forward();
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivilegeScreen()));
    if (mounted) {
      _fan.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _curve, _open);
}
