import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../organization/application/organization_providers.dart';
import '../data/purchases_repository.dart';
import '../domain/purchase.dart';
import '../domain/supplier.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(supabaseProvider));
});

final purchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  final organization = ref.watch(currentOrganizationProvider);
  return ref.watch(purchasesRepositoryProvider).getPurchases(organization.id);
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final organization = ref.watch(currentOrganizationProvider);
  return ref.watch(purchasesRepositoryProvider).getSuppliers(organization.id);
});

final purchaseProvider = FutureProvider.family<Purchase, String>((
  ref,
  purchaseId,
) {
  return ref.watch(purchasesRepositoryProvider).getPurchase(purchaseId);
});
