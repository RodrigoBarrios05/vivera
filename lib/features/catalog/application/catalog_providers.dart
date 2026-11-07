import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../organization/application/organization_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import '../domain/stock_movement.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(supabaseProvider));
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final organization = ref.watch(currentOrganizationProvider);
  return ref.watch(catalogRepositoryProvider).getProducts(organization.id);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final organization = ref.watch(currentOrganizationProvider);
  return ref.watch(catalogRepositoryProvider).getCategories(organization.id);
});

final productProvider = FutureProvider.family<Product, String>((ref, id) {
  return ref.watch(catalogRepositoryProvider).getProduct(id);
});

final stockMovementsProvider =
    FutureProvider.family<List<StockMovement>, String>((ref, productId) {
      return ref.watch(catalogRepositoryProvider).getStockMovements(productId);
    });
