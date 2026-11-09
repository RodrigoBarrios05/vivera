import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase.dart';
import '../domain/supplier.dart';

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

  Future<List<Supplier>> getSuppliers(String organizationId) async {
    final data = await _client
        .from('suppliers')
        .select('id, organization_id, name, active')
        .eq('organization_id', organizationId)
        .eq('active', true)
        .order('name', ascending: true);
    return data.map(Supplier.fromMap).toList();
  }

  Future<Supplier> createSupplier({
    required String organizationId,
    required String name,
  }) async {
    final data = await _client
        .from('suppliers')
        .insert({'organization_id': organizationId, 'name': name.trim()})
        .select('id, organization_id, name, active')
        .single();
    return Supplier.fromMap(data);
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
