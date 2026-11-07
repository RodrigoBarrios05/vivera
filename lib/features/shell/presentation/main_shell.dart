import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/offline_banner.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../purchases/application/purchases_providers.dart';
import '../../purchases/presentation/purchases_screen.dart';
import '../../sales/application/sales_providers.dart';
import '../../sales/presentation/sell_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  void _selectTab(int index) {
    setState(() => _index = index);
    switch (index) {
      case 0:
        ref.invalidate(dashboardSummaryProvider);
      case 1:
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
      case 2:
        ref.invalidate(productsProvider);
      case 3:
        ref.invalidate(purchasesProvider);
      case 4:
        ref.invalidate(salesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                DashboardScreen(
                  onOpenCatalog: () => _selectTab(1),
                  onOpenSales: () => _selectTab(2),
                  onOpenPurchases: () => _selectTab(3),
                ),
                const CatalogScreen(),
                const SellScreen(),
                const PurchasesScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Vender',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Compras',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
