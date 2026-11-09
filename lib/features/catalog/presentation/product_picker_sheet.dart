import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import 'product_form_screen.dart';

enum ProductPickerMode { sale, purchase }

enum _StockFilter { all, low, out }

Future<Product?> showProductPicker(
  BuildContext context, {
  ProductPickerMode mode = ProductPickerMode.sale,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ProductPickerSheet(mode: mode),
  );
}

class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({super.key, this.mode = ProductPickerMode.sale});

  final ProductPickerMode mode;

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  _StockFilter _stockFilter = _StockFilter.all;

  bool get _forPurchase => widget.mode == ProductPickerMode.purchase;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createProduct() async {
    final productId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (productId == null || !mounted) return;

    ref.invalidate(productsProvider);
    try {
      final product = await ref
          .read(catalogRepositoryProvider)
          .getProduct(productId);
      if (!mounted) return;
      Navigator.of(context).pop(product);
    } catch (error) {
      if (mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
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
                hintText: 'Buscar por nombre o código',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_forPurchase)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _stockFilter == _StockFilter.all,
                        onSelected: (_) =>
                            setState(() => _stockFilter = _StockFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('Stock bajo'),
                        selected: _stockFilter == _StockFilter.low,
                        onSelected: (_) =>
                            setState(() => _stockFilter = _StockFilter.low),
                      ),
                      ChoiceChip(
                        label: const Text('Sin stock'),
                        selected: _stockFilter == _StockFilter.out,
                        onSelected: (_) =>
                            setState(() => _stockFilter = _StockFilter.out),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_forPurchase)
                      TextButton.icon(
                        onPressed: _createProduct,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Crear producto'),
                      ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        'Tocá un producto para agregarlo',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
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
                  if (!matchesQuery) return false;

                  if (!_forPurchase) {
                    return product.stock > 0;
                  }

                  return switch (_stockFilter) {
                    _StockFilter.all => true,
                    _StockFilter.low =>
                      product.stock > 0 && product.stock <= product.minStock,
                    _StockFilter.out => product.stock <= 0,
                  };
                }).toList();

                if (filtered.isEmpty) {
                  final message = _forPurchase
                      ? switch (_stockFilter) {
                          _StockFilter.all =>
                            'Ningún producto coincide con tu búsqueda.',
                          _StockFilter.low =>
                            'No hay productos con stock bajo que coincidan '
                                'con tu búsqueda.',
                          _StockFilter.out =>
                            'No hay productos sin stock que coincidan '
                                'con tu búsqueda.',
                        }
                      : 'No hay productos con stock que coincidan con tu '
                            'búsqueda.';
                  return AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    message: message,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final code = product.sku?.trim();
                    final hasCode = code != null && code.isNotEmpty;
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
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          hasCode
                                              ? 'Código $code'
                                              : 'Sin código',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                        _StockBadge(
                                          product: product,
                                          locale: organization.locale,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _forPurchase ? 'Costo' : 'Precio',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    Money.format(
                                      _forPurchase
                                          ? product.costCents
                                          : product.salePriceCents,
                                      currencyCode: organization.currencyCode,
                                      locale: organization.locale,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
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

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product, required this.locale});

  final Product product;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final out = product.stock <= 0;
    final low = !out && product.stock <= product.minStock;
    final warning = out || low;
    final label = out
        ? 'Sin stock'
        : low
        ? 'Stock bajo · '
              '${Quantity.withUnit(product.stock, product.unit, locale: locale)}'
        : Quantity.withUnit(product.stock, product.unit, locale: locale);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: warning ? colors.onErrorContainer : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
