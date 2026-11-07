import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/category.dart';
import '../domain/product.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product, this.initialCategoryId});

  final Product? product;
  final String? initialCategoryId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  static const _baseUnits = [
    'pieza',
    'maceta',
    'bolsa',
    'planta',
    'árbol',
    'docena',
    'litro',
    'kilo',
    'metro',
    'otro',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _costController;
  late final TextEditingController _minStockController;
  late final TextEditingController _initialStockController;
  late final TextEditingController _notesController;
  late String _unit;
  String _categoryValue = '';
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  List<String> get _unitOptions {
    if (_baseUnits.contains(_unit)) return _baseUnits;
    return [_unit, ..._baseUnits];
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _salePriceController = TextEditingController(
      text: product == null
          ? ''
          : (product.salePriceCents / 100).toStringAsFixed(2),
    );
    _costController = TextEditingController(
      text: product == null ? '' : (product.costCents / 100).toStringAsFixed(2),
    );
    _minStockController = TextEditingController(
      text: product == null ? '0' : _plainQuantity(product.minStock),
    );
    _initialStockController = TextEditingController(text: '0');
    _notesController = TextEditingController(text: product?.notes ?? '');
    _unit = product?.unit ?? 'pieza';
    _categoryValue = product?.categoryId ?? widget.initialCategoryId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _salePriceController.dispose();
    _costController.dispose();
    _minStockController.dispose();
    _initialStockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static String _plainQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final organization = ref.read(currentOrganizationProvider);
    final repository = ref.read(catalogRepositoryProvider);
    final categoryId = _categoryValue.isEmpty ? null : _categoryValue;
    final salePrice = Money.parseCents(_salePriceController.text) ?? 0;
    final cost = Money.parseCents(_costController.text) ?? 0;
    final minStock = Quantity.parse(_minStockController.text) ?? 0;
    final initialStock = Quantity.parse(_initialStockController.text) ?? 0;

    try {
      if (_isEditing) {
        await repository.updateProduct(
          productId: widget.product!.id,
          name: _nameController.text,
          unit: _unit,
          salePriceCents: salePrice,
          costCents: cost,
          minStock: minStock,
          categoryId: categoryId,
          sku: _skuController.text.isEmpty ? null : _skuController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
      } else {
        await repository.createProduct(
          organizationId: organization.id,
          name: _nameController.text,
          unit: _unit,
          salePriceCents: salePrice,
          costCents: cost,
          minStock: minStock,
          initialStock: initialStock,
          categoryId: categoryId,
          sku: _skuController.text.isEmpty ? null : _skuController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
      }

      ref.invalidate(productsProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        AppSnack.error(context, readableError(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    final categoryItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Sin categoría')),
      for (final category in categories)
        DropdownMenuItem(value: category.id, child: Text(category.name)),
    ];

    if (_categoryValue.isNotEmpty &&
        !categories.any((category) => category.id == _categoryValue)) {
      categoryItems.add(
        DropdownMenuItem(
          value: _categoryValue,
          child: Text(widget.product?.categoryName ?? 'Categoría actual'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const SectionHeader(title: 'Datos del producto'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Ficus benjamina',
                  prefixIcon: Icon(Icons.local_florist_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Ingresá el nombre del producto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: categoryItems,
                      onChanged: (value) =>
                          setState(() => _categoryValue = value ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                      items: _unitOptions
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _unit = value ?? 'pieza'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'SKU o código interno (opcional)',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Precios'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Precio de venta',
                        prefixText:
                            '${Money.symbolFor(organization.currencyCode)} ',
                        prefixIcon: const Icon(Icons.sell_outlined),
                      ),
                      validator: _moneyValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Costo',
                        prefixText:
                            '${Money.symbolFor(organization.currencyCode)} ',
                        prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      ),
                      validator: _moneyValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'El costo se actualiza automáticamente al registrar compras.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: _isEditing ? 'Stock' : 'Stock inicial'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Stock mínimo',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
                      validator: _quantityValidator,
                    ),
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _initialStockController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Stock inicial',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: _quantityValidator,
                      ),
                    ),
                  ],
                ],
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 8),
                Text(
                  'Al crear el producto se registra un movimiento de entrada '
                  'con esta cantidad.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Notas'),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Ubicación, cuidados, proveedor habitual...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(_isEditing ? 'Guardar cambios' : 'Crear producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _moneyValidator(String? value) {
    if (Money.parseCents(value ?? '') == null) {
      return 'Monto inválido';
    }
    return null;
  }

  String? _quantityValidator(String? value) {
    if (Quantity.parse(value ?? '') == null) {
      return 'Cantidad inválida';
    }
    return null;
  }
}
