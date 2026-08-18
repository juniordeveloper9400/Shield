import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Cart with quantity stepping, live bill totals, and an empty state.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final List<_CartLine> _lines = [
    _CartLine('Dolo 650mg Tablet', 'Strip of 15 tablets', 32.5, 2),
    _CartLine('Shelcal 500 Calcium', 'Strip of 15 tablets', 118.0, 1),
    _CartLine('Zincovit Multivitamin', 'Strip of 15 tablets', 106.0, 1),
  ];

  double get _subtotal =>
      _lines.fold(0, (sum, line) => sum + line.price * line.qty);

  double get _discount => _subtotal * 0.26;

  double get _payable => _subtotal - _discount + (_subtotal > 0 ? 40 : 0);

  void _changeQty(int index, int delta) {
    setState(() {
      final next = _lines[index].qty + delta;
      if (next <= 0) {
        _lines.removeAt(index);
      } else {
        _lines[index].qty = next;
      }
    });
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
          'Cart',
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
      body: _lines.isEmpty ? const _EmptyCart() : _buildFilled(),
      bottomNavigationBar: _lines.isEmpty ? null : _buildCheckoutBar(),
    );
  }

  Widget _buildFilled() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _lines.length; i++) ...[
                _CartRow(
                  line: _lines[i],
                  onIncrement: () => _changeQty(i, 1),
                  onDecrement: () => _changeQty(i, -1),
                ),
                if (i != _lines.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _BillSummary(
          subtotal: _subtotal,
          discount: _discount,
          delivery: 40,
          payable: _payable,
        ),
      ],
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total payable',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '₹${_payable.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Proceed to checkout',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final _CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartRow({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.pageTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line.pack,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${(line.price * line.qty).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QtyStepper(
            qty: line.qty,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyStepper({
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brandBlue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove_rounded, onTap: onDecrement),
          SizedBox(
            width: 30,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 32,
        height: 34,
        child: Icon(icon, size: 17, color: AppColors.brandBlue),
      ),
    );
  }
}

class _BillSummary extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double delivery;
  final double payable;

  const _BillSummary({
    required this.subtotal,
    required this.discount,
    required this.delivery,
    required this.payable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bill summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _BillRow(label: 'Item total', value: '₹${subtotal.toStringAsFixed(2)}'),
          _BillRow(
            label: 'SHIELD discount (26%)',
            value: '-₹${discount.toStringAsFixed(2)}',
            valueColor: AppColors.brandGreenDark,
          ),
          _BillRow(label: 'Delivery fee', value: '₹${delivery.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _BillRow(
            label: 'Total payable',
            value: '₹${payable.toStringAsFixed(2)}',
            emphasise: true,
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasise;

  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    final weight = emphasise ? FontWeight.w800 : FontWeight.w500;
    final size = emphasise ? 16.0 : 14.5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size,
                fontWeight: weight,
                color: emphasise ? AppColors.textDark : AppColors.textBody,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: emphasise ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 62,
            color: AppColors.searchBorder,
          ),
          const SizedBox(height: 14),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add medicines to get started',
            style: TextStyle(fontSize: 14.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CartLine {
  final String name;
  final String pack;
  final double price;
  int qty;

  _CartLine(this.name, this.pack, this.price, this.qty);
}
