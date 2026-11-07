import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase.dart';

class PurchasesRepository {
  PurchasesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Purchase>> getPurchases(
    String organizationId, {
    int limit = 100,
  }) async {
    final data = await _client
        .from('purchases')
        .select('*, profiles(full_name)')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map(Purchase.fromMap).toList();
  }

  Future<Purchase> getPurchase(String purchaseId) async {
    final data = await _client
        .from('purchases')
        .select('*, profiles(full_name), purchase_items(*)')
        .eq('id', purchaseId)
        .single();
    return Purchase.fromMap(data);
  }

  Future<String> createPurchase({
    required String organizationId,
    required List<Map<String, dynamic>> items,
    String? supplierName,
    String? notes,
  }) async {
    final result = await _client.rpc(
      'create_purchase',
      params: {
        'p_organization_id': organizationId,
        'p_items': items,
        'p_supplier_name': supplierName?.trim(),
        'p_notes': notes?.trim(),
      },
    );
    return result as String;
  }
}
