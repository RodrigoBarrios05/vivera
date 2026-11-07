import '../../catalog/domain/product.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final double quantity;

  int get subtotalCents => (product.salePriceCents * quantity).round();

  CartLine copyWith({double? quantity}) {
    return CartLine(product: product, quantity: quantity ?? this.quantity);
  }
}
