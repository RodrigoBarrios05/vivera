import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/section_header.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/product_picker_sheet.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../application/purchases_providers.dart';
import '../domain/supplier.dart';

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _DraftLine {
  const _DraftLine({
    required this.product,
    required this.quantity,
    required this.unitCostCents,
  });

  final Product product;
  final double quantity;
  final int unitCostCents;

  int get subtotalCents => (unitCostCents * quantity).round();
}

class _LineValues {
  const _LineValues({required this.quantity, required this.unitCostCents});

  final double quantity;
  final int unitCostCents;
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _notesController = TextEditingController();
  final List<_DraftLine> _lines = [];
  Supplier? _supplier;
  bool _saving = false;

  int get _totalCents =>
      _lines.fold(0, (sum, line) => sum + line.subtotalCents);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    final product = await showProductPicker(
      context,
      mode: ProductPickerMode.purchase,
    );
    if (product == null || !mounted) return;

    final existingIndex = _lines.indexWhere(
      (line) => line.product.id == product.id,
    );
    final existing = existingIndex >= 0 ? _lines[existingIndex] : null;

    final values = await showDialog<_LineValues>(
      context: context,
      builder: (_) => _LineEditorDialog(
        product: product,
        initialQuantity: existing?.quantity,
        initialUnitCostCents: existing?.unitCostCents ?? product.costCents,
      ),
    );
    if (values == null || !mounted) return;

    setState(() {
      final newLine = _DraftLine(
        product: product,
        quantity: values.quantity,
        unitCostCents: values.unitCostCents,
      );
      if (existingIndex >= 0) {
        _lines[existingIndex] = newLine;
      } else {
        _lines.add(newLine);
      }
    });
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final values = await showDialog<_LineValues>(
      context: context,
      builder: (_) => _LineEditorDialog(
        product: line.product,
        initialQuantity: line.quantity,
        initialUnitCostCents: line.unitCostCents,
      ),
    );
    if (values == null || !mounted) return;

    setState(() {
      _lines[index] = _DraftLine(
        product: line.product,
        quantity: values.quantity,
        unitCostCents: values.unitCostCents,
      );
    });
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      AppSnack.error(context, 'Agregá al menos un producto a la compra.');
      return;
    }

    setState(() => _saving = true);
    final organization = ref.read(currentOrganizationProvider);

    try {
      await ref
          .read(purchasesRepositoryProvider)
          .createPurchase(
            organizationId: organization.id,
            items: _lines
                .map(
                  (line) => {
                    'product_id': line.product.id,
                    'quantity': line.quantity,
                    'unit_cost_cents': line.unitCostCents,
                  },
                )
                .toList(),
            supplierName: _supplier?.name,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );

      ref.invalidate(purchasesProvider);
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

  Future<void> _createSupplier() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _SupplierNameDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final organization = ref.read(currentOrganizationProvider);
    final suppliers =
        ref.read(suppliersProvider).asData?.value ?? const <Supplier>[];
    if (suppliers.any(
      (supplier) => supplier.name.toLowerCase() == name.toLowerCase(),
    )) {
      AppSnack.error(context, 'Ya existe un proveedor con ese nombre.');
      return;
    }

    try {
      final supplier = await ref
          .read(purchasesRepositoryProvider)
          .createSupplier(organizationId: organization.id, name: name);
      ref.invalidate(suppliersProvider);
      if (!mounted) return;
      setState(() => _supplier = supplier);
      AppSnack.success(context, 'Proveedor creado.');
    } catch (error) {
      if (mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(currentOrganizationProvider);
    final suppliersAsync = ref.watch(suppliersProvider);
    final suppliers = suppliersAsync.asData?.value ?? const <Supplier>[];
    final selectedSupplierId =
        suppliers.any((supplier) => supplier.id == _supplier?.id)
        ? _supplier!.id
        : '';
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva compra')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader(title: 'Proveedor')),
                TextButton.icon(
                  onPressed: _createSupplier,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedSupplierId),
              initialValue: selectedSupplierId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Proveedor (opcional)',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Sin proveedor')),
                for (final supplier in suppliers)
                  DropdownMenuItem(
                    value: supplier.id,
                    child: Text(supplier.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value.isEmpty) {
                  setState(() => _supplier = null);
                  return;
                }
                for (final supplier in suppliers) {
                  if (supplier.id == value) {
                    setState(() => _supplier = supplier);
                    return;
                  }
                }
              },
            ),
            if (suppliersAsync.hasError) ...[
              const SizedBox(height: 8),
              Text(
                'No se pudieron cargar los proveedores.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.error),
              ),
            ] else if (suppliersAsync.hasValue && suppliers.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Todavía no hay proveedores. Creá el primero con “Nuevo”.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: SectionHeader(title: 'Productos')),
                TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            if (_lines.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Agregá los productos que ingresaron y su costo unitario.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var index = 0; index < _lines.length; index++) ...[
                _PurchaseLineCard(
                  line: _lines[index],
                  currencyCode: organization.currencyCode,
                  locale: organization.locale,
                  onEdit: () => _editLine(index),
                  onRemove: () => setState(() => _lines.removeAt(index)),
                ),
                if (index < _lines.length - 1) const SizedBox(height: 8),
              ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total de la compra',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      Money.format(
                        _totalCents,
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Notas'),
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Factura, condiciones, aclaraciones... (opcional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving || _lines.isEmpty ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Registrando...' : 'Registrar compra'),
            ),
            const SizedBox(height: 8),
            Text(
              'El stock aumenta y el costo promedio se recalcula al confirmar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseLineCard extends StatelessWidget {
  const _PurchaseLineCard({
    required this.line,
    required this.currencyCode,
    required this.locale,
    required this.onEdit,
    required this.onRemove,
  });

  final _DraftLine line;
  final String currencyCode;
  final String locale;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Quantity.withUnit(line.quantity, line.product.unit, locale: locale)} × '
                    '${Money.format(line.unitCostCents, currencyCode: currencyCode, locale: locale)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Money.format(
                line.subtotalCents,
                currencyCode: currencyCode,
                locale: locale,
              ),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Quitar',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: colors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineEditorDialog extends StatefulWidget {
  const _LineEditorDialog({
    required this.product,
    this.initialQuantity,
    this.initialUnitCostCents,
  });

  final Product product;
  final double? initialQuantity;
  final int? initialUnitCostCents;

  @override
  State<_LineEditorDialog> createState() => _LineEditorDialogState();
}

class _LineEditorDialogState extends State<_LineEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.initialQuantity == null
          ? '1'
          : _plainQuantity(widget.initialQuantity!),
    );
    _costController = TextEditingController(
      text: widget.initialUnitCostCents == null
          ? ''
          : (widget.initialUnitCostCents! / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  static String _plainQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _LineValues(
        quantity: Quantity.parse(_quantityController.text) ?? 0,
        unitCostCents: Money.parseCents(_costController.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final organization = ProviderScope.containerOf(context)
        .read(currentOrganizationProvider);

    return AlertDialog(
      title: Text(widget.product.name),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock actual: '
              '${Quantity.withUnit(widget.product.stock, widget.product.unit, locale: organization.locale)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: widget.product.unit,
              ),
              validator: (value) {
                final quantity = Quantity.parse(value ?? '');
                if (quantity == null || quantity <= 0) {
                  return 'Cantidad inválida';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Costo unitario',
                prefixText: '${Money.symbolFor(organization.currencyCode)} ',
              ),
              validator: (value) {
                if (Money.parseCents(value ?? '') == null) {
                  return 'Costo inválido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Aplicar')),
      ],
    );
  }
}

class _SupplierNameDialog extends StatefulWidget {
  const _SupplierNameDialog();

  @override
  State<_SupplierNameDialog> createState() => _SupplierNameDialogState();
}

class _SupplierNameDialogState extends State<_SupplierNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo proveedor'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Nombre',
          hintText: 'Ej. Vivero Central',
          prefixIcon: Icon(Icons.store_outlined),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Crear')),
      ],
    );
  }
}
