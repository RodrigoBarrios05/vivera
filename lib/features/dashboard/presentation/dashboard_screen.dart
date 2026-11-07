import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/product_detail_screen.dart';
import '../../catalog/presentation/product_form_screen.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/domain/dashboard_summary.dart';
import '../../organization/application/organization_providers.dart';
import '../../session/application/session_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenCatalog,
    required this.onOpenSales,
    required this.onOpenPurchases,
  });

  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenSales;
  final VoidCallback onOpenPurchases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final colors = Theme.of(context).colorScheme;
    final firstName = session.displayName.split(' ').first;

    Future<void> refresh() async {
      ref.invalidate(dashboardSummaryProvider);
      try {
        await ref.read(dashboardSummaryProvider.future);
      } catch (_) {
        // El error se muestra en la vista.
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola, $firstName'),
            Text(
              organization.name,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: AsyncValueView<DashboardSummary>(
          value: summary,
          onRetry: refresh,
          builder: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _TodaySalesCard(summary: data),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Inventario',
                      value: Money.format(
                        data.inventoryValueCents,
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      color: colors.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Stock bajo',
                      value: '${data.lowStockCount}',
                      color: data.lowStockCount > 0
                          ? colors.error
                          : colors.primary,
                      onTap: onOpenCatalog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Accesos rápidos'),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Vender',
                      color: colors.primary,
                      onTap: onOpenSales,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.local_shipping_rounded,
                      label: 'Compra',
                      color: colors.tertiary,
                      onTap: onOpenPurchases,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.add_box_outlined,
                      label: 'Producto',
                      color: colors.secondary,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProductFormScreen(),
                          ),
                        );
                        ref.invalidate(productsProvider);
                        ref.invalidate(dashboardSummaryProvider);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Stock bajo',
                action: TextButton(
                  onPressed: onOpenCatalog,
                  child: const Text('Ver catálogo'),
                ),
              ),
              if (data.lowStock.isEmpty)
                _AllGoodCard()
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < data.lowStock.length;
                        index++
                      ) ...[
                        _LowStockTile(
                          product: data.lowStock[index],
                          currencyCode: organization.currencyCode,
                          locale: organization.locale,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  productId: data.lowStock[index].id,
                                ),
                              ),
                            );
                            ref.invalidate(dashboardSummaryProvider);
                          },
                        ),
                        if (index < data.lowStock.length - 1)
                          const Divider(height: 1),
                      ],
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

class _TodaySalesCard extends StatelessWidget {
  const _TodaySalesCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final organization = ProviderScope.containerOf(context)
        .read(currentOrganizationProvider);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: 0.82)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ventas de hoy',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Money.format(
                    summary.todaySalesCents,
                    currencyCode: organization.currencyCode,
                    locale: organization.locale,
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.todaySalesCount == 1
                      ? '1 venta registrada'
                      : '${summary.todaySalesCount} ventas registradas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: colors.onPrimary,
              size: 34,
            ),
          ),
        ],
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 14),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({
    required this.product,
    required this.currencyCode,
    required this.locale,
    required this.onTap,
  });

  final LowStockProduct product;
  final String currencyCode;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
          size: 20,
        ),
      ),
      title: Text(product.name),
      subtitle: Text(
        'Quedan ${Quantity.withUnit(product.stock, product.unit, locale: locale)}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _AllGoodCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Todo el stock está en orden.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
