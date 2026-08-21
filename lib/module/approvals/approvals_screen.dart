import 'package:flutter/material.dart';

import '../../money.dart';
import '../../theme/app_colors.dart';
import 'approval.dart';

/// The Approvals destination: prescriptions the pharmacist has priced and is
/// waiting on the member to confirm.
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Approvals',
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
      body: ListenableBuilder(
        listenable: ApprovalService.instance,
        builder: (context, _) {
          final service = ApprovalService.instance;
          final awaiting = service.awaiting;
          final settled = service.settled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Intro(pending: service.pendingCount),
              const SizedBox(height: 16),
              if (awaiting.isEmpty)
                const _AllClear()
              else
                for (final approval in awaiting) ...[
                  _ApprovalCard(approval: approval),
                  const SizedBox(height: 12),
                ],
              if (settled.isNotEmpty) ...[
                const SizedBox(height: 10),
                const _SectionLabel('Already answered'),
                const SizedBox(height: 10),
                for (final approval in settled) ...[
                  _ApprovalCard(approval: approval),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// What the screen is for, and how much of it is outstanding.
class _Intro extends StatelessWidget {
  final int pending;

  const _Intro({required this.pending});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pending > 0 ? AppColors.creamTint : AppColors.greenTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              pending > 0 ? Icons.fact_check_outlined : Icons.verified_rounded,
              size: 22,
              color: pending > 0
                  ? AppColors.goldAccent
                  : AppColors.brandGreenDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending == 0
                      ? 'Nothing waiting on you'
                      : pending == 1
                      ? '1 order needs your approval'
                      : '$pending orders need your approval',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Nothing is dispensed or charged until you say yes.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final Approval approval;

  const _ApprovalCard({required this.approval});

  void _answer(BuildContext context, {required bool approved}) {
    final service = ApprovalService.instance;
    if (approved) {
      service.approve(approval.id);
    } else {
      service.decline(approval.id);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '${approval.orderRef} approved · we will dispense it now'
                : '${approval.orderRef} declined · the pharmacist will call '
                      'you',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: approval.isAwaiting ? AppColors.brandBlue : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.orderRef,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${approval.patientName} · ${approval.raisedOn}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: approval.status),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in approval.items) ...[
            _ItemRow(item: item),
            const SizedBox(height: 10),
          ],
          if (approval.pharmacistNote.isNotEmpty) ...[
            const SizedBox(height: 2),
            _PharmacistNote(text: approval.pharmacistNote),
            const SizedBox(height: 12),
          ],
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${formatRupees(approval.total)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          if (approval.isAwaiting) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _answer(context, approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.dangerLine),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => _answer(context, approved: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Approve & dispense',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ApprovalItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.pack} · Qty ${item.quantity}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              // The changed lines are the ones worth reading, so they say so
              // on the line rather than only in the note below.
              if (item.isChanged) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1, right: 5),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: AppColors.goldAccent,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.note,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '₹${formatRupees(item.price)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _PharmacistNote extends StatelessWidget {
  final String text;

  const _PharmacistNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageTint,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 8),
            child: Icon(
              Icons.support_agent_rounded,
              size: 17,
              color: AppColors.brandBlue,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
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

class _StatusChip extends StatelessWidget {
  final ApprovalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color tint, Color ink) = switch (status) {
      ApprovalStatus.awaiting => (AppColors.creamTint, AppColors.goldAccent),
      ApprovalStatus.approved => (
        AppColors.greenTint,
        AppColors.brandGreenDark,
      ),
      ApprovalStatus.declined => (AppColors.dangerTint, AppColors.danger),
    };

    return Semantics(
      // The chip is one word; a screen reader gets the whole sentence.
      label: status.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status.shortLabel,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: const Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 40,
            color: AppColors.brandGreenDeep,
          ),
          SizedBox(height: 10),
          Text(
            'All caught up',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'When a pharmacist prices your prescription, it will appear here '
            'for you to approve.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
