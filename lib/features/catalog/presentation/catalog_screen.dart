import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import 'categories_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryId;
  bool _onlyLowStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
    try {
      await ref.read(productsProvider.future);
    } catch (_) {
      // El error ya se muestra en la lista.
    }
  }

  Future<void> _openForm({Product? product}) async {
    final changed = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (changed != null) {
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(dashboardSummaryProvider);
    }
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
    ref.invalidate(productsProvider);
    ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> _openCategories() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _categoryId = null;
      _onlyLowStock = false;
    });
  }

  List<Product> _filter(List<Product> products) {
    final query = _query.trim().toLowerCase();
    return products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false);
      final matchesCategory =
          _categoryId == null || product.categoryId == _categoryId;
      final matchesStock = !_onlyLowStock || product.isLowStock;
      return matchesQuery && matchesCategory && matchesStock;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;
    final categories = categoriesAsync.asData?.value ?? const [];
    final hasFilters =
        _query.isNotEmpty || _categoryId != null || _onlyLowStock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            tooltip: 'Categorías',
            onPressed: _openCategories,
            icon: const Icon(Icons.category_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
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
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                const SizedBox(width: 8),
                for (final category in categories) ...[
                  ChoiceChip(
                    label: Text(category.name),
                    selected: _categoryId == category.id,
                    onSelected: (_) => setState(
                      () => _categoryId = _categoryId == category.id
                          ? null
                          : category.id,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  avatar: _onlyLowStock
                      ? null
                      : const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text('Stock bajo'),
                  selected: _onlyLowStock,
                  selectedColor: colors.errorContainer,
                  onSelected: (value) => setState(() => _onlyLowStock = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: AsyncValueView<List<Product>>(
                value: productsAsync,
                onRetry: _refresh,
                builder: (products) {
                  if (products.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: AppEmptyState(
                            icon: Icons.local_florist_rounded,
                            title: 'Tu catálogo está vacío',
                            message: 'Agregá tu primer producto para empezar a vender y controlar el stock.',
                            action: FilledButton.icon(
                              onPressed: () => _openForm(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Nuevo producto'),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final filtered = _filter(products);
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 40),
                      children: [
                        AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Sin resultados',
                          message:
                              'Probá con otra búsqueda o quitá los filtros.',
                          action: hasFilters
                              ? OutlinedButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(
                                    Icons.filter_alt_off_rounded,
                                  ),
                                  label: const Text('Quitar filtros'),
                                )
                              : null,
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            filtered.length == 1
                                ? '1 producto'
                                : '${filtered.length} productos',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        );
                      }
                      final product = filtered[index - 1];
                      return _ProductTile(
                        product: product,
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                        onTap: () => _openDetail(product),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo producto'),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.currencyCode,
    required this.locale,
    required this.onTap,
  });

  final Product product;
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: product.isLowStock
                      ? colors.errorContainer
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_florist_rounded,
                  color: product.isLowStock
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer,
                  size: 24,
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
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (product.categoryName != null &&
                            product.categoryName!.isNotEmpty)
                          product.categoryName!,
                        if (product.sku != null && product.sku!.isNotEmpty)
                          'Código ${product.sku}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    _StockBadge(product: product, locale: locale),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.format(
                      product.salePriceCents,
                      currencyCode: currencyCode,
                      locale: locale,
                    ),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
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
    final low = product.isLowStock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: low ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        Quantity.withUnit(product.stock, product.unit, locale: locale),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: low ? colors.onErrorContainer : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
