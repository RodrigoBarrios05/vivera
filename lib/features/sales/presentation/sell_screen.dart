import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_form_screen.dart';
import '../../organization/application/organization_providers.dart';
import '../application/sales_providers.dart';
import '../domain/cart_line.dart';
import 'checkout_screen.dart';
import 'sales_history_screen.dart';

class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key});

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CartLine? _cartLineFor(CartState cart, Product product) {
    for (final line in cart.lines) {
      if (line.product.id == product.id) return line;
    }
    return null;
  }

  void _addToCart(Product product) {
    final cart = ref.read(cartControllerProvider);
    final existing = _cartLineFor(cart, product);

    if (product.stock <= 0) {
      AppSnack.error(context, '${product.name} no tiene stock disponible.');
      return;
    }

    if (existing != null && existing.quantity + 1 > product.stock) {
      AppSnack.error(
        context,
        'Solo hay ${Quantity.format(product.stock)} ${product.unit} de ${product.name}.',
      );
      return;
    }

    ref.read(cartControllerProvider.notifier).add(product);
  }

  Future<void> _openCheckout() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
    ref.invalidate(productsProvider);
  }

  Future<void> _clearCart() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Vaciar carrito',
      message: 'Se quitarán todos los productos de la venta actual.',
      confirmLabel: 'Vaciar',
      destructive: true,
    );
    if (confirmed) {
      ref.read(cartControllerProvider.notifier).clear();
    }
  }

  Future<void> _createProduct() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProductFormScreen()));
    if (changed == true) {
      ref.invalidate(productsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.watch(cartControllerProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vender'),
        actions: [
          IconButton(
            tooltip: 'Historial de ventas',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              onPressed: _clearCart,
              icon: const Icon(Icons.remove_shopping_cart_outlined),
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
                hintText: 'Buscar producto para vender',
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
          Expanded(
            child: AsyncValueView<List<Product>>(
              value: productsAsync,
              onRetry: () => ref.invalidate(productsProvider),
              builder: (products) {
                if (products.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.local_florist_rounded,
                    title: 'No hay productos para vender',
                    message: 'Primero agregá productos a tu catálogo con su precio y stock.',
                    action: FilledButton.icon(
                      onPressed: _createProduct,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear producto'),
                    ),
                  );
                }

                final query = _query.trim().toLowerCase();
                final filtered = products.where((product) {
                  if (query.isEmpty) return true;
                  return product.name.toLowerCase().contains(query) ||
                      (product.sku?.toLowerCase().contains(query) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    message: 'No encontramos productos con esa búsqueda.',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 700
                        ? 3
                        : 2,
                    mainAxisExtent: 176,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final line = _cartLineFor(cart, product);
                    return _SellProductCard(
                      product: product,
                      cartQuantity: line?.quantity ?? 0,
                      currencyCode: organization.currencyCode,
                      locale: organization.locale,
                      onTap: product.stock > 0
                          ? () => _addToCart(product)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          if (!cart.isEmpty)
            Material(
              color: colors.surfaceContainerHigh,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.lines.length == 1
                                  ? '1 producto'
                                  : '${cart.lines.length} productos',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            Text(
                              Money.format(
                                cart.totalCents,
                                currencyCode: organization.currencyCode,
                                locale: organization.locale,
                              ),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _openCheckout,
                        icon: const Icon(Icons.point_of_sale_rounded),
                        label: const Text('Cobrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellProductCard extends StatelessWidget {
  const _SellProductCard({
    required this.product,
    required this.cartQuantity,
    required this.currencyCode,
    required this.locale,
    required this.onTap,
  });

  final Product product;
  final double cartQuantity;
  final String currencyCode;
  final String locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outOfStock = product.stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: outOfStock ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.local_florist_rounded,
                        size: 19,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const Spacer(),
                    if (cartQuantity > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          Quantity.format(cartQuantity, locale: locale),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      )
                    else if (outOfStock)
                      Text(
                        'Sin stock',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  Quantity.withUnit(
                    product.stock,
                    product.unit,
                    locale: locale,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: product.isLowStock
                        ? colors.error
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Money.format(
                    product.salePriceCents,
                    currencyCode: currencyCode,
                    locale: locale,
                  ),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
