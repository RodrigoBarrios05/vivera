import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../catalog/domain/product.dart';
import '../../organization/application/organization_providers.dart';
import '../data/sales_repository.dart';
import '../domain/cart_line.dart';
import '../domain/sale.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.watch(supabaseProvider));
});

final salesProvider = FutureProvider<List<Sale>>((ref) async {
  final organization = ref.watch(currentOrganizationProvider);
  return ref.watch(salesRepositoryProvider).getSales(organization.id);
});

final saleProvider = FutureProvider.family<Sale, String>((ref, saleId) {
  return ref.watch(salesRepositoryProvider).getSale(saleId);
});

class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  int get itemCount =>
      lines.fold(0, (sum, line) => sum + line.quantity.toInt());

  int get totalCents => lines.fold(0, (sum, line) => sum + line.subtotalCents);

  CartState copyWith({List<CartLine>? lines}) {
    return CartState(lines: lines ?? this.lines);
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(Product product) {
    final index = state.lines.indexWhere(
      (line) => line.product.id == product.id,
    );

    if (index >= 0) {
      final current = state.lines[index];
      final nextQuantity = current.quantity + 1;
      if (nextQuantity > product.stock) return;
      final lines = [...state.lines];
      lines[index] = current.copyWith(quantity: nextQuantity);
      state = state.copyWith(lines: lines);
      return;
    }

    if (product.stock <= 0) return;
    state = state.copyWith(
      lines: [
        ...state.lines,
        CartLine(product: product, quantity: 1),
      ],
    );
  }

  void setQuantity(String productId, double quantity) {
    final index = state.lines.indexWhere(
      (line) => line.product.id == productId,
    );
    if (index < 0) return;
    final line = state.lines[index];
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    final capped = quantity > line.product.stock
        ? line.product.stock
        : quantity;
    final lines = [...state.lines];
    lines[index] = line.copyWith(quantity: capped);
    state = state.copyWith(lines: lines);
  }

  void increment(String productId) {
    final line = state.lines.firstWhere((line) => line.product.id == productId);
    setQuantity(productId, line.quantity + 1);
  }

  void decrement(String productId) {
    final line = state.lines.firstWhere((line) => line.product.id == productId);
    setQuantity(productId, line.quantity - 1);
  }

  void remove(String productId) {
    state = state.copyWith(
      lines: state.lines.where((line) => line.product.id != productId).toList(),
    );
  }

  void clear() {
    state = const CartState();
  }
}
