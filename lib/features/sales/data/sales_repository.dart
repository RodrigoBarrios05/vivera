import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sale.dart';

class SalesRepository {
  SalesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Sale>> getSales(String organizationId, {int limit = 100}) async {
    final data = await _client
        .from('sales')
        .select('*, profiles!sales_created_by_fkey(full_name)')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map(Sale.fromMap).toList();
  }

  Future<Sale> getSale(String saleId) async {
    final data = await _client
        .from('sales')
        .select('*, profiles!sales_created_by_fkey(full_name), sale_items(*)')
        .eq('id', saleId)
        .single();
    return Sale.fromMap(data);
  }

  Future<String> createSale({
    required String organizationId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'create_sale',
      params: {
        'p_organization_id': organizationId,
        'p_items': items,
        'p_payment_method': paymentMethod,
        'p_notes': notes?.trim(),
      },
    );
    return result as String;
  }

  Future<void> cancelSale({
    required String organizationId,
    required String saleId,
    required String reason,
  }) async {
    await _client.rpc(
      'cancel_sale',
      params: {
        'p_organization_id': organizationId,
        'p_sale_id': saleId,
        'p_reason': reason.trim(),
      },
    );
  }
}
