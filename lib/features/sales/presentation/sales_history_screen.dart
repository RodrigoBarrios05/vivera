import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../organization/application/organization_providers.dart';
import '../application/sales_providers.dart';
import '../domain/sale.dart';
import 'sale_detail_screen.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(salesProvider);
    try {
      await ref.read(salesProvider.future);
    } catch (_) {
      // El error se muestra en la vista.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de ventas'),
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
        child: AsyncValueView<List<Sale>>(
          value: salesAsync,
          onRetry: () => _refresh(ref),
          builder: (sales) {
            if (sales.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: const AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Todavía no hay ventas',
                      message: 'Cuando registres una venta, va a aparecer acá con su detalle.',
                    ),
                  ),
                ],
              );
            }

            final completed = sales.where((sale) => !sale.isCancelled).toList();
            final totalCents = completed.fold<int>(
              0,
              (sum, sale) => sum + sale.totalCents,
            );

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: sales.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: colors.onPrimaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  completed.length == 1
                                      ? '1 venta completada'
                                      : '${completed.length} ventas completadas',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Últimas ${sales.length} ventas',
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

                final sale = sales[index - 1];
                return _SaleTile(
                  sale: sale,
                  currencyCode: organization.currencyCode,
                  locale: organization.locale,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SaleDetailScreen(saleId: sale.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.currencyCode,
    required this.locale,
    required this.onTap,
  });

  final Sale sale;
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
                  color: sale.isCancelled
                      ? colors.surfaceContainerHighest
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  sale.isCancelled
                      ? Icons.cancel_outlined
                      : Icons.point_of_sale_rounded,
                  size: 22,
                  color: sale.isCancelled
                      ? colors.onSurfaceVariant
                      : colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Venta #${sale.saleNumber}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (sale.isCancelled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Anulada',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Dates.dateTime(sale.createdAt)} · ${paymentMethodLabel(sale.paymentMethod)}',
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
                  sale.totalCents,
                  currencyCode: currencyCode,
                  locale: locale,
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  decoration: sale.isCancelled
                      ? TextDecoration.lineThrough
                      : null,
                  color: sale.isCancelled ? colors.onSurfaceVariant : null,
                ),
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
