import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';
import '../domain/product.dart';
import '../domain/stock_movement.dart';

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<Product>> getProducts(String organizationId) async {
    final data = await _client
        .from('products')
        .select('*, categories(name)')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('name', ascending: true);
    return data.map(Product.fromMap).toList();
  }

  Future<Product> getProduct(String productId) async {
    final data = await _client
        .from('products')
        .select('*, categories(name)')
        .eq('id', productId)
        .single();
    return Product.fromMap(data);
  }

  Future<List<Category>> getCategories(String organizationId) async {
    final data = await _client
        .from('categories')
        .select('id, organization_id, name, sort_order, active')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return data.map(Category.fromMap).toList();
  }

  Future<String> createProduct({
    required String organizationId,
    required String name,
    required int salePriceCents,
    required int costCents,
    required double minStock,
    required double initialStock,
    String? categoryId,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'create_product',
      params: {
        'p_organization_id': organizationId,
        'p_name': name.trim(),
        'p_category_id': categoryId,
        'p_unit': 'pieza',
        'p_sale_price_cents': salePriceCents,
        'p_cost_cents': costCents,
        'p_min_stock': minStock,
        'p_initial_stock': initialStock,
        'p_notes': notes?.trim(),
      },
    );
    return result as String;
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required int salePriceCents,
    required int costCents,
    required double minStock,
    String? categoryId,
    String? notes,
  }) async {
    await _client
        .from('products')
        .update({
          'name': name.trim(),
          'sale_price_cents': salePriceCents,
          'cost_cents': costCents,
          'min_stock': minStock,
          'category_id': categoryId,
          'notes': notes?.trim(),
        })
        .eq('id', productId);
  }

  Future<void> setProductActive({
    required String productId,
    required bool active,
  }) async {
    await _client
        .from('products')
        .update({'active': active})
        .eq('id', productId);
  }

  Future<void> adjustStock({
    required String organizationId,
    required String productId,
    required double newStock,
    required String reason,
  }) async {
    await _client.rpc(
      'adjust_stock',
      params: {
        'p_organization_id': organizationId,
        'p_product_id': productId,
        'p_new_stock': newStock,
        'p_reason': reason.trim(),
      },
    );
  }

  Future<List<StockMovement>> getStockMovements(String productId) async {
    final data = await _client
        .from('stock_movements')
        .select('*, profiles(full_name)')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(30);
    return data.map(StockMovement.fromMap).toList();
  }

  Future<Category> createCategory({
    required String organizationId,
    required String name,
    required int sortOrder,
  }) async {
    final data = await _client
        .from('categories')
        .insert({
          'organization_id': organizationId,
          'name': name.trim(),
          'sort_order': sortOrder,
        })
        .select('id, organization_id, name, sort_order, active')
        .single();
    return Category.fromMap(data);
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    required bool active,
  }) async {
    await _client
        .from('categories')
        .update({'name': name.trim(), 'active': active})
        .eq('id', categoryId);
  }
}
