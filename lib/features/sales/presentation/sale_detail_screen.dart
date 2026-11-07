import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../application/sales_providers.dart';
import '../domain/sale.dart';
import '../domain/sale_item.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  bool _cancelling = false;

  Future<void> _refresh() async {
    ref.invalidate(saleProvider(widget.saleId));
    ref.invalidate(salesProvider);
    try {
      await ref.read(saleProvider(widget.saleId).future);
    } catch (_) {
      // El error se muestra en la vista.
    }
  }

  Future<void> _cancel(Sale sale) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelSaleDialog(),
    );
    if (reason == null) return;

    setState(() => _cancelling = true);
    final organization = ref.read(currentOrganizationProvider);
    try {
      await ref
          .read(salesRepositoryProvider)
          .cancelSale(
            organizationId: organization.id,
            saleId: sale.id,
            reason: reason,
          );
      ref.invalidate(saleProvider(widget.saleId));
      ref.invalidate(salesProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (!mounted) return;
      AppSnack.success(context, 'Venta anulada. El stock fue restaurado.');
    } catch (error) {
      if (mounted) {
        AppSnack.error(context, readableError(error));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleProvider(widget.saleId));
    final organization = ref.watch(currentOrganizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de venta'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncValueView<Sale>(
        value: saleAsync,
        onRetry: _refresh,
        builder: (sale) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SaleHeader(
                sale: sale,
                currencyCode: organization.currencyCode,
                locale: organization.locale,
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Productos'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < sale.items.length; index++) ...[
                      _SaleItemRow(
                        item: sale.items[index],
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      if (index < sale.items.length - 1)
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
                        label: 'Método de pago',
                        value: paymentMethodLabel(sale.paymentMethod),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Fecha',
                        value: Dates.dateTime(sale.createdAt),
                      ),
                      if (sale.createdByName != null &&
                          sale.createdByName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(
                          label: 'Registrada por',
                          value: sale.createdByName!,
                        ),
                      ],
                      if (sale.notes != null &&
                          sale.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoRow(label: 'Notas', value: sale.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              if (sale.isCancelled) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'Anulación'),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Venta anulada',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                        if (sale.cancelledAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            Dates.dateTime(sale.cancelledAt!),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                          ),
                        ],
                        if (sale.cancelReason != null &&
                            sale.cancelReason!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Motivo: ${sale.cancelReason}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (!sale.isCancelled) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _cancelling ? null : () => _cancel(sale),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: _cancelling
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('Anular venta'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anular una venta devuelve los productos al stock y no se '
                  'puede deshacer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleHeader extends StatelessWidget {
  const _SaleHeader({
    required this.sale,
    required this.currencyCode,
    required this.locale,
  });

  final Sale sale;
  final String currencyCode;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Venta #${sale.saleNumber}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sale.isCancelled
                        ? colors.errorContainer
                        : colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sale.isCancelled ? 'Anulada' : 'Completada',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: sale.isCancelled
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Total',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              Money.format(
                sale.totalCents,
                currencyCode: currencyCode,
                locale: locale,
              ),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                decoration: sale.isCancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${Dates.dateTime(sale.createdAt)} · ${paymentMethodLabel(sale.paymentMethod)}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleItemRow extends StatelessWidget {
  const _SaleItemRow({
    required this.item,
    required this.currencyCode,
    required this.locale,
  });

  final SaleItem item;
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
                  '${Quantity.withUnit(item.quantity, item.unit, locale: locale)} × ${Money.format(item.unitPriceCents, currencyCode: currencyCode, locale: locale)}',
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

class _CancelSaleDialog extends StatefulWidget {
  const _CancelSaleDialog();

  @override
  State<_CancelSaleDialog> createState() => _CancelSaleDialogState();
}

class _CancelSaleDialogState extends State<_CancelSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Anular venta'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Los productos volverán al stock. Esta acción no se puede deshacer.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ej. Venta duplicada, devolución...',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Indicá el motivo';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _submit,
          child: const Text('Anular venta'),
        ),
      ],
    );
  }
}
