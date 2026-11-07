import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';

Future<Product?> showProductPicker(BuildContext context) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const ProductPickerSheet(),
  );
}

class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({super.key});

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyWithStock = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Elegir producto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o SKU',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                FilterChip(
                  selected: _onlyWithStock,
                  onSelected: (value) => setState(() => _onlyWithStock = value),
                  avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Solo con stock'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tocá un producto para agregarlo',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Product>>(
              value: productsAsync,
              onRetry: () => ref.invalidate(productsProvider),
              builder: (products) {
                final query = _query.trim().toLowerCase();
                final filtered = products.where((product) {
                  final matchesQuery =
                      query.isEmpty ||
                      product.name.toLowerCase().contains(query) ||
                      (product.sku?.toLowerCase().contains(query) ?? false);
                  final matchesStock = !_onlyWithStock || product.stock > 0;
                  return matchesQuery && matchesStock;
                }).toList();

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    message: _onlyWithStock
                        ? 'No hay productos con stock que coincidan con tu búsqueda.'
                        : 'Ningún producto coincide con tu búsqueda.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(product),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.local_florist_rounded,
                                  color: colors.onPrimaryContainer,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Quantity.withUnit(
                                        product.stock,
                                        product.unit,
                                        locale: organization.locale,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                Money.format(
                                  product.salePriceCents,
                                  currencyCode: organization.currencyCode,
                                  locale: organization.locale,
                                ),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
