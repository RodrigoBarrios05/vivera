import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../organization/application/organization_providers.dart';
import '../application/purchases_providers.dart';
import '../domain/purchase.dart';
import 'purchase_detail_screen.dart';
import 'purchase_form_screen.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(purchasesProvider);
    try {
      await ref.read(purchasesProvider.future);
    } catch (_) {
      // El error se muestra en la vista.
    }
  }

  Future<void> _createPurchase(BuildContext context, WidgetRef ref) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PurchaseFormScreen()));
    if (changed == true) {
      ref.invalidate(purchasesProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: AsyncValueView<List<Purchase>>(
          value: purchasesAsync,
          onRetry: () => _refresh(ref),
          builder: (purchases) {
            if (purchases.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: AppEmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'Todavía no hay compras',
                      message: 'Registrá el ingreso de mercancía para actualizar el stock y el costo de tus productos.',
                      action: FilledButton.icon(
                        onPressed: () => _createPurchase(context, ref),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nueva compra'),
                      ),
                    ),
                  ),
                ],
              );
            }

            final totalCents = purchases.fold<int>(
              0,
              (sum, purchase) => sum + purchase.totalCents,
            );

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: purchases.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colors.tertiaryContainer,
                            child: Icon(
                              Icons.inventory_rounded,
                              color: colors.onTertiaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  purchases.length == 1
                                      ? '1 compra registrada'
                                      : '${purchases.length} compras registradas',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Inversión en mercancía',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            Money.format(
                              totalCents,
                              currencyCode: organization.currencyCode,
                              locale: organization.locale,
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final purchase = purchases[index - 1];
                return _PurchaseTile(
                  purchase: purchase,
                  currencyCode: organization.currencyCode,
                  locale: organization.locale,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          PurchaseDetailScreen(purchaseId: purchase.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createPurchase(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva compra'),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.currencyCode,
    required this.locale,
    required this.onTap,
  });

  final Purchase purchase;
  final String currencyCode;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
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
                  size: 22,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.supplierName?.trim().isNotEmpty == true
                          ? purchase.supplierName!
                          : 'Compra #${purchase.purchaseNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Compra #${purchase.purchaseNumber} · '
                      '${Dates.dateTime(purchase.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.format(
                  purchase.totalCents,
                  currencyCode: currencyCode,
                  locale: locale,
                ),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
