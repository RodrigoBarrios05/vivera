import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../organization/application/organization_providers.dart';
import '../application/purchases_providers.dart';
import '../domain/purchase.dart';
import '../domain/purchase_item.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  final String purchaseId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(purchaseProvider(purchaseId));
    try {
      await ref.read(purchaseProvider(purchaseId).future);
    } catch (_) {
      // El error se muestra en la vista.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseAsync = ref.watch(purchaseProvider(purchaseId));
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de compra'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncValueView<Purchase>(
        value: purchaseAsync,
        onRetry: () => _refresh(ref),
        builder: (purchase) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              color: colors.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compra #${purchase.purchaseNumber}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Dates.dateTime(purchase.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Money.format(
                          purchase.totalCents,
                          currencyCode: organization.currencyCode,
                          locale: organization.locale,
                        ),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Productos'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < purchase.items.length;
                      index++
                    ) ...[
                      _PurchaseItemRow(
                        item: purchase.items[index],
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      if (index < purchase.items.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Información'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Proveedor',
                        value: purchase.supplierName?.trim().isNotEmpty == true
                            ? purchase.supplierName!
                            : 'Sin proveedor',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Fecha',
                        value: Dates.dateTime(purchase.createdAt),
                      ),
                      if (purchase.createdByName != null &&
                          purchase.createdByName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          label: 'Registrada por',
                          value: purchase.createdByName!,
                        ),
                      ],
                      if (purchase.notes != null &&
                          purchase.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(label: 'Notas', value: purchase.notes!),
                      ],
                    ],
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

class _PurchaseItemRow extends StatelessWidget {
  const _PurchaseItemRow({
    required this.item,
    required this.currencyCode,
    required this.locale,
  });

  final PurchaseItem item;
  final String currencyCode;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Quantity.withUnit(item.quantity, item.unit, locale: locale)} × '
                  '${Money.format(item.unitCostCents, currencyCode: currencyCode, locale: locale)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.format(
              item.subtotalCents,
              currencyCode: currencyCode,
              locale: locale,
            ),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
