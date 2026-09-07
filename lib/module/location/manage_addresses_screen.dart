import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/neon/address_repository.dart';
import '../../theme/app_colors.dart';
import 'address_book.dart';
import 'address_form_screen.dart';

/// "Manage addresses" — reached from the account menu and the location
/// sheet: every address on file, with add, edit, remove, and a way to pick
/// which one deliveries go to.
class ManageAddressesScreen extends StatelessWidget {
  const ManageAddressesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => const AddressFormScreen()),
    );
  }

  Future<void> _edit(BuildContext context, Address address) async {
    await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(existing: address),
      ),
    );
  }

  Future<void> _remove(BuildContext context, Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text(
          '${address.summary} will no longer be offered at checkout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final remoteId = address.remoteId;
      if (remoteId != null) {
        unawaited(AddressRepository.instance.softDelete(remoteId));
      }
      AddressBook.instance.remove(address.id);
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
          'Saved Addresses',
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
        listenable: AddressBook.instance,
        builder: (context, _) {
          final book = AddressBook.instance;
          final addresses = book.addresses;
          if (addresses.isEmpty) {
            return const _EmptyState();
          }

          final deliverTo = book.deliverTo;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return _AddressCard(
                address: address,
                isDeliveringHere: identical(address, deliverTo),
                onTap: () => book.select(address),
                onEdit: () => _edit(context, address),
                onRemove: () => _remove(context, address),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        backgroundColor: AppColors.brandBlue,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 54,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 14),
            Text(
              'No saved addresses yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Add a delivery address so checkout has somewhere to send '
              'your order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textBody),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved address: who it is labelled for, the full line, and — tapped
/// anywhere but the two icons — the choice of delivering here.
class _AddressCard extends StatelessWidget {
  final Address address;
  final bool isDeliveringHere;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _AddressCard({
    required this.address,
    required this.isDeliveringHere,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDeliveringHere ? AppColors.offerTint : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDeliveringHere
                  ? AppColors.brandBlue
                  : AppColors.border,
              width: isDeliveringHere ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDeliveringHere
                      ? AppColors.brandBlue
                      : AppColors.pageTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  address.label.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDeliveringHere
                        ? AppColors.white
                        : AppColors.textBody,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.receiver,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address.summary,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (address.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '+91 ${address.phone}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (isDeliveringHere) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.brandBlue,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Delivering here',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                iconSize: 20,
                color: AppColors.textBody,
                tooltip: 'Edit address',
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 20,
                color: AppColors.textMuted,
                tooltip: 'Remove address',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
