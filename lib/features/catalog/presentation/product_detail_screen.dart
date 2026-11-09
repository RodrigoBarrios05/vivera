import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import '../domain/stock_movement.dart';
import 'product_form_screen.dart';
import 'stock_adjust_sheet.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Future<void> _refresh() async {
    ref.invalidate(productProvider(widget.productId));
    ref.invalidate(stockMovementsProvider(widget.productId));
    ref.invalidate(productsProvider);
    ref.invalidate(dashboardSummaryProvider);
    try {
      await ref.read(productProvider(widget.productId).future);
    } catch (_) {
      // El error se muestra en la vista.
    }
  }

  Future<void> _edit(Product product) async {
    final changed = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (changed != null) {
      await _refresh();
    }
  }

  Future<void> _adjustStock(Product product) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => StockAdjustSheet(product: product),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _toggleActive(Product product) async {
    final deactivating = product.active;
    final confirmed = await showConfirmDialog(
      context,
      title: deactivating ? 'Desactivar producto' : 'Reactivar producto',
      message: deactivating
          ? 'El producto dejará de aparecer en el catálogo y no se podrá '
                'vender. Las ventas y compras históricas se conservan.'
          : 'El producto volverá a aparecer en el catálogo y se podrá vender.',
      confirmLabel: deactivating ? 'Desactivar' : 'Reactivar',
      destructive: deactivating,
    );
    if (!confirmed) return;

    try {
      await ref
          .read(catalogRepositoryProvider)
          .setProductActive(productId: product.id, active: !deactivating);
      await _refresh();
      if (!mounted) return;
      AppSnack.success(
        context,
        deactivating
            ? 'Producto desactivado. Ya no aparece en el catálogo.'
            : 'Producto reactivado.',
      );
    } catch (error) {
      if (mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productProvider(widget.productId));
    final product = productAsync.asData?.value;
    final organization = ref.watch(currentOrganizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Producto'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (product != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _edit(product);
                  case 'stock':
                    _adjustStock(product);
                  case 'active':
                    _toggleActive(product);
                }
              },
              itemBuilder: (_) => [
                _menuItem(
                  value: 'edit',
                  icon: Icons.edit_outlined,
                  label: 'Editar producto',
                ),
                _menuItem(
                  value: 'stock',
                  icon: Icons.tune_rounded,
                  label: 'Ajustar stock',
                ),
                _menuItem(
                  value: 'active',
                  icon: product.active
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: product.active ? 'Desactivar' : 'Reactivar',
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncValueView<Product>(
        value: productAsync,
        onRetry: _refresh,
        builder: (product) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ProductHeader(product: product),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.sell_outlined,
                      label: 'Precio de venta',
                      value: Money.format(
                        product.salePriceCents,
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Costo',
                      value: Money.format(
                        product.costCents,
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock actual',
                      value: Quantity.withUnit(
                        product.stock,
                        product.unit,
                        locale: organization.locale,
                      ),
                      color: product.isLowStock
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Stock mínimo',
                      value: Quantity.withUnit(
                        product.minStock,
                        product.unit,
                        locale: organization.locale,
                      ),
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Valor del inventario',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        Money.format(
                          product.inventoryValueCents.round(),
                          currencyCode: organization.currencyCode,
                          locale: organization.locale,
                        ),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(title: 'Movimientos de stock'),
                  ),
                  TextButton.icon(
                    onPressed: () => _adjustStock(product),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Ajustar'),
                  ),
                ],
              ),
              _MovementsCard(productId: product.id, unit: product.unit),
              if (product.notes != null &&
                  product.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: 'Notas'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      product.notes!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_florist_rounded,
                    color: colors.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (product.categoryName != null &&
                              product.categoryName!.isNotEmpty)
                            product.categoryName!,
                          if (product.sku != null &&
                              product.sku!.trim().isNotEmpty)
                            'Código ${product.sku}',
                          if (product.sku == null ||
                              product.sku!.trim().isEmpty)
                            'Sin código',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: product.active ? 'Activo' : 'Inactivo',
                  background: product.active
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  foreground: product.active
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
                if (product.isLowStock)
                  _StatusChip(
                    label: 'Stock bajo',
                    background: colors.errorContainer,
                    foreground: colors.onErrorContainer,
                  ),
                _StatusChip(
                  label: 'Margen ${product.marginPercent}%',
                  background: colors.secondaryContainer,
                  foreground: colors.onSecondaryContainer,
                ),
                _StatusChip(
                  label: product.unit,
                  background: colors.surfaceContainerHighest,
                  foreground: colors.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementsCard extends ConsumerWidget {
  const _MovementsCard({required this.productId, required this.unit});

  final String productId;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider(productId));
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: movementsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                readableError(error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(stockMovementsProvider(productId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (movements) {
          if (movements.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: colors.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Todavía no hay movimientos registrados.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              for (var index = 0; index < movements.length; index++) ...[
                _MovementTile(movement: movements[index], unit: unit),
                if (index < movements.length - 1) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.unit});

  final StockMovement movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final positive = movement.quantityDelta >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: positive ? colors.primaryContainer : colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              positive ? Icons.add_rounded : Icons.remove_rounded,
              size: 20,
              color: positive
                  ? colors.onPrimaryContainer
                  : colors.onErrorContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movementTypeLabel(movement.movementType),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  Dates.dateTime(movement.createdAt),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (movement.reason != null &&
                    movement.reason!.trim().isNotEmpty)
                  Text(
                    movement.reason!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${Quantity.withUnit(movement.quantityDelta, unit)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: positive ? colors.primary : colors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Quedan ${Quantity.format(movement.stockAfter)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
