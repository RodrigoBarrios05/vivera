import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';

class StockAdjustSheet extends ConsumerStatefulWidget {
  const StockAdjustSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends ConsumerState<StockAdjustSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockController;
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(
      text: _plainQuantity(widget.product.stock),
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _reasonController.dispose();
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
    try {
      await ref
          .read(catalogRepositoryProvider)
          .adjustStock(
            organizationId: organization.id,
            productId: widget.product.id,
            newStock: Quantity.parse(_stockController.text) ?? 0,
            reason: _reasonController.text,
          );
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
    final colors = Theme.of(context).colorScheme;
    final organization = ref.watch(currentOrganizationProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajustar stock',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _stockController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Stock real',
                  helperText:
                      'Stock actual: '
                      '${Quantity.withUnit(widget.product.stock, widget.product.unit, locale: organization.locale)}',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  suffixText: widget.product.unit,
                ),
                validator: (value) {
                  if (Quantity.parse(value ?? '') == null) {
                    return 'Ingresá una cantidad válida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo del ajuste',
                  hintText: 'Ej. Conteo físico, producto dañado...',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Indicá el motivo del ajuste';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar ajuste'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
