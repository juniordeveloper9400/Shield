import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../money.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_flow.dart';
import '../registration/registration_flow.dart';
import '../registration/registration_service.dart';
import '../wallet/wallet_service.dart';
import 'privilege_card_face.dart';
import 'privilege_tier.dart';

/// The privilege programme: pick a card, load it, and SHIELD adds 10%.
class PrivilegeScreen extends StatefulWidget {
  const PrivilegeScreen({super.key});

  @override
  State<PrivilegeScreen> createState() => _PrivilegeScreenState();
}

class _PrivilegeScreenState extends State<PrivilegeScreen> {
  final TextEditingController _custom = TextEditingController();

  /// The card carousel at the top. A fraction under one so the neighbouring
  /// cards show at the edges — which is what says there are more to switch to.
  final PageController _pages = PageController(viewportFraction: 0.86);

  PrivilegeTier? _selected;
  String? _customError;

  int _page = 0;

  /// True while the carousel is being driven from a tap rather than a swipe,
  /// so the page callback does not undo the selection that caused the move.
  bool _syncing = false;

  @override
  void dispose() {
    _custom.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// The face shown at [index].
  ///
  /// A custom amount is issued as the top card, so it is drawn onto that card
  /// rather than left showing the published ₹50,000 the member did not pick.
  PrivilegeTier _faceAt(int index) {
    final tiers = PrivilegeProgramme.tiers;
    final chosen = _selected;
    final isCustom =
        chosen != null && !tiers.any((tier) => tier.amount == chosen.amount);
    if (isCustom && index == tiers.length - 1) {
      return chosen;
    }
    return tiers[index];
  }

  void _select(PrivilegeTier tier) {
    setState(() {
      _selected = tier;
      _custom.clear();
      _customError = null;
    });
    final index = PrivilegeProgramme.tiers.indexWhere(
      (option) => option.amount == tier.amount,
    );
    if (index >= 0) {
      _switchTo(index);
    }
  }

  /// Moves the carousel without letting the move re-select anything.
  Future<void> _switchTo(int index) async {
    if (!_pages.hasClients || _page == index) {
      return;
    }
    _syncing = true;
    await _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _syncing = false;
  }

  /// Swiping to a card picks it: on a wallet of cards, the one in your hand
  /// is the one you are choosing.
  void _onPageChanged(int index) {
    setState(() => _page = index);
    if (_syncing) {
      return;
    }
    setState(() {
      _selected = PrivilegeProgramme.tiers[index];
      _custom.clear();
      _customError = null;
    });
  }

  void _onCustomChanged(String value) {
    final amount = int.tryParse(value.trim());
    setState(() {
      if (value.trim().isEmpty) {
        _selected = null;
        _customError = null;
        return;
      }
      if (amount == null || !PrivilegeProgramme.isValidAmount(amount)) {
        _selected = null;
        _customError =
            'Enter a multiple of ₹${formatRupees(PrivilegeProgramme.step)}, '
            'up to ₹${formatRupees(PrivilegeProgramme.maxAmount)}';
        return;
      }
      _customError = null;
      _selected = PrivilegeProgramme.tierFor(amount);
    });
    // A custom amount is issued as the top card, so the carousel is brought
    // to it and draws the typed figure on its face.
    if (_customError == null && _selected != null) {
      _switchTo(PrivilegeProgramme.tiers.length - 1);
    }
  }

  Future<void> _activate() async {
    final tier = _selected;
    if (tier == null) {
      return;
    }

    // Loading a card moves real money, so the member must be signed in and registered.
    await AuthFlow.guard(context, () async {
      if (!RegistrationService.instance.isRegistered) {
        final registered = await RegistrationFlow.show(context);
        if (!registered && !RegistrationService.instance.isRegistered) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please complete registration to activate the Privilege Programme',
                  ),
                ),
              );
          }
          return;
        }
      }

      if (!mounted) return;

      WalletService.instance.topUp(
        amount: tier.amount,
        bonus: tier.bonus,
        label: '${tier.name} activation',
        bonusLabel: '${tier.name} bonus · 10%',
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${tier.name} activated · ${tier.creditedLabel} added to your '
              'wallet',
            ),
          ),
        );
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tier = _selected;

    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Privilege Programme',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _CardCarousel(
            controller: _pages,
            page: _page,
            selected: tier,
            holder: RegistrationService.instance.profile?.name ?? '',
            faceAt: _faceAt,
            onPageChanged: _onPageChanged,
            // _select moves the carousel itself, so a tapped pip and a tapped
            // row travel by exactly the same path.
            onSwitchTo: (index) => _select(PrivilegeProgramme.tiers[index]),
          ),
          const SizedBox(height: 18),
          const _Explainer(),
          const SizedBox(height: 18),
          const Text(
            'Choose your card',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in PrivilegeProgramme.tiers) ...[
            _TierCard(
              tier: option,
              isSelected: option.amount == tier?.amount,
              onTap: () => _select(option),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          _CustomAmountField(
            controller: _custom,
            error: _customError,
            onChanged: _onCustomChanged,
          ),
          const SizedBox(height: 18),
          const _TermsBox(),
        ],
      ),
      bottomNavigationBar: _ActivateBar(tier: tier, onActivate: _activate),
    );
  }
}

/// The cards themselves, one to a page, switched by swiping or by tapping a
/// pip beneath them.
///
/// The programme is a set of cards, so the screen opens with the cards rather
/// than with a description of them. Switching repaints the face in that
/// tier's colour, which is the whole difference between silver, gold and
/// platinum said without a word.
class _CardCarousel extends StatelessWidget {
  final PageController controller;
  final int page;
  final PrivilegeTier? selected;
  final String holder;
  final PrivilegeTier Function(int index) faceAt;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSwitchTo;

  const _CardCarousel({
    required this.controller,
    required this.page,
    required this.selected,
    required this.holder,
    required this.faceAt,
    required this.onPageChanged,
    required this.onSwitchTo,
  });

  /// Half the gap between one card and the next.
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final tiers = PrivilegeProgramme.tiers;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The page is a fixed share of the width, so the height that keeps a
        // card card-shaped follows from it rather than being guessed at.
        final faceWidth =
            constraints.maxWidth * controller.viewportFraction - _gap * 2;

        return Column(
          children: [
            SizedBox(
              height: faceWidth / PrivilegeCardFace.aspectRatio,
              child: PageView.builder(
                controller: controller,
                onPageChanged: onPageChanged,
                itemCount: tiers.length,
                itemBuilder: (context, index) {
                  final tier = faceAt(index);
                  final isCurrent = index == page;
                  final isSelected = selected?.amount == tier.amount;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gap),
                    child: AnimatedScale(
                      // The card in hand stands slightly proud of the two
                      // behind it.
                      scale: isCurrent ? 1 : 0.92,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: GestureDetector(
                        onTap: () => onSwitchTo(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: tier.accent.withValues(
                                  alpha: isSelected ? 0.45 : 0.2,
                                ),
                                blurRadius: isSelected ? 18 : 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          foregroundDecoration: isSelected
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 2,
                                  ),
                                )
                              : null,
                          child: PrivilegeCardFace(
                            tier: tier,
                            holder: holder,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < tiers.length; index++)
                  _SwitchPip(
                    tier: tiers[index],
                    isCurrent: index == page,
                    onTap: () => onSwitchTo(index),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One pip per card, in that card's colour, and a way to switch to it.
class _SwitchPip extends StatelessWidget {
  final PrivilegeTier tier;
  final bool isCurrent;
  final VoidCallback onTap;

  const _SwitchPip({
    required this.tier,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isCurrent,
      label: tier.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: isCurrent ? 26 : 9,
            height: 7,
            decoration: BoxDecoration(
              // A BoxDecoration rather than Container's colour: the tier
              // stripe on the row below is found by its ColoredBox, and a
              // second one here would be a second card of that colour.
              color: isCurrent
                  ? tier.accent
                  : tier.accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 20,
                color: AppColors.brandGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'PRIVILEGE PROGRAMME',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Load your wallet, we add 10%',
            style: TextStyle(
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Load ₹10,000 and ₹11,000 lands in your wallet. Every card carries '
            'the same 10% — a bigger card simply loads more.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final PrivilegeTier tier;
  final bool isSelected;
  final VoidCallback onTap;

  const _TierCard({
    required this.tier,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // The card wears its own colour when picked, and shows it as a stripe
      // and a medallion when not — so the five read as five cards rather than
      // five rows of the same card.
      color: isSelected ? tier.tint : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? tier.accent : AppColors.border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full-height stripe in the tier's colour.
                SizedBox(width: 6, child: ColoredBox(color: tier.accent)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.white : tier.tint,
                            shape: BoxShape.circle,
                            border: Border.all(color: tier.accent, width: 1.4),
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_rounded
                                : Icons.shield_outlined,
                            size: 20,
                            color: tier.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tier.name,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: tier.accent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.blurb,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Wrap: the amounts run past a Row at 320px.
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    tier.amountLabel,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      // The bonus keeps the money-green it
                                      // shares with every other saving in the
                                      // app; only the card's identity changes
                                      // per tier.
                                      color: AppColors.greenTint,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      '+ ${tier.bonusLabel} free',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandGreenDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tier.creditedLabel} credited to your wallet',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 22,
                          color: isSelected
                              ? tier.accent
                              : AppColors.searchBorder,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;

  const _CustomAmountField({
    required this.controller,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Or load another amount',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Any multiple of ₹10,000. The 10% is the same.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          // Digits only at source, so the error can never be about letters.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(7),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: '10000',
            errorText: error,
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.searchBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.brandBlue,
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsBox extends StatelessWidget {
  const _TermsBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          _TermLine('The bonus is credited to your SHIELD wallet at once.'),
          _TermLine('Wallet money is spent on orders and lab bookings.'),
          _TermLine('The bonus is store credit, and is not withdrawable.'),
        ],
      ),
    );
  }
}

class _TermLine extends StatelessWidget {
  final String text;

  const _TermLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: AppColors.brandGreenDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivateBar extends StatelessWidget {
  final PrivilegeTier? tier;
  final VoidCallback onActivate;

  const _ActivateBar({required this.tier, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final selected = tier;

    return Material(
      color: AppColors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected == null ? '—' : selected.creditedLabel,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: selected?.accent ?? AppColors.textDark,
                      ),
                    ),
                    Text(
                      selected == null
                          ? 'Pick a card'
                          : 'You pay ${selected.amountLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Disabled until a card is chosen, so this cannot load an amount
              // nobody picked.
              FilledButton(
                onPressed: selected == null ? null : onActivate,
                style: FilledButton.styleFrom(
                  // Wears the chosen card's colour, so the bar and the card
                  // agree on what is about to be activated.
                  backgroundColor: selected?.accent ?? AppColors.brandBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Activate',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
