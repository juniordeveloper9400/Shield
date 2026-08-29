import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '../../widgets/upload_picker.dart';
import '../location/address_book.dart';
import '../location/address_form_screen.dart';
import '../registration/registration_service.dart';
import '../registration/shield_store.dart';
import 'checkout_chrome.dart';
import 'checkout_order.dart';
import 'payment_method.dart';
import 'payment_receipt.dart';
import 'receipt_form.dart';
import 'shield_payee.dart';

typedef CheckoutComplete = Future<void> Function(PaymentReceipt receipt);

/// Where the checkout's pre-filled store came from — drives the note under the
/// picker.
enum _StoreSource { registration, deliveryAddress, directoryDefault }

/// Manual payment checkout shared by product orders and privilege plans.
class CheckoutScreen extends StatefulWidget {
  final CheckoutOrder order;
  final CheckoutComplete onComplete;

  /// Where to go once the receipt is in. When set, the checkout is replaced by
  /// this screen — the order-placed confirmation for a cart. When null it just
  /// pops with `true`, which is what the privilege flow expects.
  final WidgetBuilder? successScreen;

  const CheckoutScreen({
    super.key,
    required this.order,
    required this.onComplete,
    this.successScreen,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final ReceiptFormController _receipt = ReceiptFormController();
  final TextEditingController _agent = TextEditingController();
  final TextEditingController _bankReference = TextEditingController();
  final ReceiptPicker _picker = const ReceiptPicker();

  int _step = 1;
  PaymentMethod _method = PaymentMethods.bankTransfer;
  late ShieldStore _store;
  late StoreBankAccount _account;

  /// Where the fixed store came from, which decides the note under it.
  _StoreSource _storeSource = _StoreSource.directoryDefault;

  @override
  void initState() {
    super.initState();
    _syncDefaultStore();
    _bankReference.addListener(() {
      _receipt.setBankReference(_bankReference.text);
    });
    _receipt.addListener(_refresh);
    // The store follows the member's registration, so keep watching it —
    // completing or editing registration while this screen is open still moves
    // it to the branch they signed up against.
    RegistrationService.instance.addListener(_onSourcesChanged);
    if (widget.order.requiresDelivery) {
      // So step one unlocks the moment an address is saved on the form pushed
      // over this screen — and the fallback store tracks that address.
      AddressBook.instance.addListener(_onSourcesChanged);
    }
  }

  /// Re-resolves the store from the member's sources, then repaints.
  void _onSourcesChanged() {
    _syncDefaultStore();
    _refresh();
  }

  /// Resolves the fixed store and the bank account that goes with it.
  ///
  /// The branch from the member's registration comes first — that is the one
  /// they signed up (or activated a plan) against, and the whole point of this
  /// field is to carry it through to checkout, not to offer a choice. Only when
  /// there is no registration does it fall back to the branch nearest the
  /// delivery address, then to the top of the directory.
  void _syncDefaultStore() {
    final registered = RegistrationService.instance.profile?.store;
    if (registered != null) {
      _storeSource = _StoreSource.registration;
      _store = registered;
      _account = ShieldPayees.forStore(registered).first;
      return;
    }

    final pincode = AddressBook.instance.deliverTo?.pincode;
    final nearby = pincode != null ? StoreDirectory.suggestFor(pincode) : null;
    if (nearby != null) {
      _storeSource = _StoreSource.deliveryAddress;
      _store = nearby;
    } else {
      _storeSource = _StoreSource.directoryDefault;
      _store = StoreDirectory.all.first;
    }
    _account = ShieldPayees.forStore(_store).first;
  }

  /// The line under the store field explaining where the fixed value came from,
  /// or null when there is nothing to explain.
  String? get _storeNote {
    switch (_storeSource) {
      case _StoreSource.registration:
        return 'The store you chose during registration. Every order on your '
            'account is served by this branch.';
      case _StoreSource.deliveryAddress:
        return 'Nearest branch to your delivery address. Complete registration '
            'to pin your own store here.';
      case _StoreSource.directoryDefault:
        return null;
    }
  }

  @override
  void dispose() {
    _receipt.removeListener(_refresh);
    _receipt.dispose();
    _agent.dispose();
    _bankReference.dispose();
    RegistrationService.instance.removeListener(_onSourcesChanged);
    if (widget.order.requiresDelivery) {
      AddressBook.instance.removeListener(_onSourcesChanged);
    }
    super.dispose();
  }

  bool get _hasDeliveryAddress =>
      !widget.order.requiresDelivery ||
      AddressBook.instance.deliverTo != null;

  // The agent code is optional — an order placed without one is still valid —
  // so it does not gate the step. Only a live method and (where the order
  // ships) a delivery address do.
  bool get _canContinue => _method.isLive && _hasDeliveryAddress;

  bool get _canSubmit => _canContinue && _receipt.isComplete && !_receipt.busy;

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _chooseAccount(StoreBankAccount? account) {
    if (account != null) {
      setState(() => _account = account);
    }
  }

  void _chooseMethod(PaymentMethod method) {
    if (!method.isLive) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(method.comingSoonNote)));
      return;
    }
    setState(() => _method = method);
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pick(source);
    if (file != null) {
      _receipt.setFile(file);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    _receipt.setBusy(true);
    try {
      final file = _receipt.file!;
      await widget.onComplete(
        PaymentReceipt(
          method: _method,
          fileName: file.name,
          bytes: file.bytes,
          orderReference: widget.order.reference,
          storeId: _store.id,
          bankAccount: _account,
          agentCode: _agent.text.trim(),
          bankReference: _receipt.bankReference.isEmpty
              ? null
              : _receipt.bankReference,
          submittedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      final success = widget.successScreen;
      if (success != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: success),
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        _receipt.setBusy(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageTint,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Payment checkout',
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
          CheckoutSteps(active: _step),
          const SizedBox(height: 14),
          _OrderSummary(order: widget.order),
          const SizedBox(height: 14),
          if (_step == 1) ...[
            if (widget.order.requiresDelivery) ...[
              _DeliveryPanel(
                address: AddressBook.instance.deliverTo,
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddressFormScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _StorePanel(
              store: _store,
              account: _account,
              agent: _agent,
              storeNote: _storeNote,
              onAccountChanged: _chooseAccount,
            ),
            const SizedBox(height: 14),
            _MethodPanel(selected: _method, onSelect: _chooseMethod),
          ] else ...[
            _BankTransferPanel(order: widget.order, account: _account),
            const SizedBox(height: 14),
            _ReceiptPanel(
              controller: _receipt,
              bankReference: _bankReference,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
            ),
          ],
        ],
      ),
      bottomNavigationBar: CheckoutActionBar(
        amountLabel: widget.order.amountLabel,
        label: _step == 1 ? 'Next' : widget.order.submitLabel,
        busy: _receipt.busy,
        onPressed: _step == 1
            ? (_canContinue ? () => setState(() => _step = 2) : null)
            : (_canSubmit ? _submit : null),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final CheckoutOrder order;

  const _OrderSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            order.subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
          if (order.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                    Text(
                      line.amountLabel,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: line.isCredit
                            ? AppColors.brandGreenDark
                            : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Divider(height: 18, color: AppColors.border),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transfer amount',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                order.amountLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Reference: ${order.reference}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// The delivery address block, shown on step one for orders that ship. The
/// address is required: without one, [_CheckoutScreenState._canContinue] holds
/// the flow on this step.
class _DeliveryPanel extends StatelessWidget {
  final Address? address;
  final VoidCallback onEdit;

  const _DeliveryPanel({required this.address, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final address = this.address;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CheckoutHeading('Delivery address'),
              const Spacer(),
              if (address != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (address == null) ...[
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.add_location_alt_outlined, size: 20),
              label: const Text('Add delivery address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandBlue,
                side: const BorderSide(color: AppColors.brandBlue, width: 1.4),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Required to place the order.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ] else
            Container(
              decoration: BoxDecoration(
                color: AppColors.pageTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.offerTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          address.label.label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address.receiver,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.summary,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
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

class _StorePanel extends StatelessWidget {
  final ShieldStore store;
  final StoreBankAccount account;
  final TextEditingController agent;

  /// A line under the store field saying where the fixed value came from, or
  /// null when there is nothing to explain.
  final String? storeNote;
  final ValueChanged<StoreBankAccount?> onAccountChanged;

  const _StorePanel({
    required this.store,
    required this.account,
    required this.agent,
    required this.storeNote,
    required this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = ShieldPayees.forStore(store);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutHeading('Your store & agent'),
          const SizedBox(height: 10),
          // Not a picker: this is the branch pinned to the member's account at
          // registration / plan activation, and every order is served by it.
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.pageTint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your store',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        store.addressLine,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          if (storeNote != null) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppColors.brandGreenDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    storeNote!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: agent,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Agent code (optional)',
              hintText: 'Enter it only if an agent is helping you',
              helperText: 'Leave blank if you do not have one',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          const CheckoutHeading('Choose bank account'),
          const SizedBox(height: 9),
          for (final option in accounts)
            _AccountTile(
              account: option,
              selected: option.id == account.id,
              onTap: () => onAccountChanged(option),
            ),
        ],
      ),
    );
  }
}

class _MethodPanel extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelect;

  const _MethodPanel({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutHeading('Payment option'),
          const SizedBox(height: 10),
          for (final method in PaymentMethods.all) ...[
            _MethodTile(
              method: method,
              selected: method.id == selected.id,
              onTap: () => onSelect(method),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? method.tint : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? method.accent : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: method.tint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(method.icon, size: 20, color: method.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      method.blurb,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!method.isLive) const ComingSoonPill(),
              if (method.isLive)
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? method.accent : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankTransferPanel extends StatelessWidget {
  final CheckoutOrder order;
  final StoreBankAccount account;

  const _BankTransferPanel({required this.order, required this.account});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutHeading('Transfer to this account'),
          const SizedBox(height: 10),
          _BankRow('Account name', account.accountName),
          _BankRow('Account number', account.accountNumber),
          _BankRow('IFSC', account.ifsc),
          _BankRow('Bank', account.bank),
          _BankRow('Branch', account.branch),
          _BankRow('Amount', order.amountLabel),
          _BankRow('Reference', order.reference),
        ],
      ),
    );
  }
}

class _ReceiptPanel extends StatelessWidget {
  final ReceiptFormController controller;
  final TextEditingController bankReference;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _ReceiptPanel({
    required this.controller,
    required this.bankReference,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final file = controller.file;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckoutHeading('Upload payment receipt'),
          const SizedBox(height: 8),
          const Text(
            'After transfer, upload the bank or UPI receipt screenshot.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              UploadSourceTile(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                enabled: !controller.busy,
                onTap: onCamera,
              ),
              const SizedBox(width: 10),
              UploadSourceTile(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                enabled: !controller.busy,
                onTap: onGallery,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (file != null)
            UploadedFileCard(
              name: file.name,
              bytes: file.bytes,
              tooLarge: controller.tooLarge,
              limitLabel: kReceiptLimitLabel,
              readyLabel: 'ready to submit',
              removeLabel: 'Remove receipt',
              onRemove: controller.clearFile,
            ),
          const SizedBox(height: 12),
          TextField(
            controller: bankReference,
            decoration: const InputDecoration(
              labelText: 'UTR / transaction ID',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final StoreBankAccount account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.chipBlueTint : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.brandBlue : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.brandBlue : AppColors.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.accountName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      account.shortLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  final String label;
  final String value;

  const _BankRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}
