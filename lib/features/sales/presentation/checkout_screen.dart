import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/section_header.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../application/sales_providers.dart';
import '../domain/cart_line.dart';
import 'sale_detail_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const _paymentMethods = [
    ('efectivo', 'Efectivo', Icons.payments_outlined),
    ('transferencia', 'Transferencia', Icons.account_balance_outlined),
    ('tarjeta', 'Tarjeta', Icons.credit_card_rounded),
    ('otro', 'Otro', Icons.more_horiz_rounded),
  ];

  final _notesController = TextEditingController();
  String _paymentMethod = 'efectivo';
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _editQuantity(CartLine line) async {
    final quantity = await showDialog<double>(
      context: context,
      builder: (_) => _QuantityDialog(
        productName: line.product.name,
        unit: line.product.unit,
        initialQuantity: line.quantity,
        maxQuantity: line.product.stock,
      ),
    );
    if (quantity == null) return;
    ref
        .read(cartControllerProvider.notifier)
        .setQuantity(line.product.id, quantity);
  }

  Future<void> _submit() async {
    final cart = ref.read(cartControllerProvider);
    if (cart.isEmpty) return;

    setState(() => _saving = true);
    final organization = ref.read(currentOrganizationProvider);

    try {
      final saleId = await ref
          .read(salesRepositoryProvider)
          .createSale(
            organizationId: organization.id,
            items: cart.lines
                .map(
                  (line) => {
                    'product_id': line.product.id,
                    'quantity': line.quantity,
                  },
                )
                .toList(),
            paymentMethod: _paymentMethod,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );

      ref.read(cartControllerProvider.notifier).clear();
      ref.invalidate(productsProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (!mounted) return;
      AppSnack.success(context, 'Venta registrada');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: saleId)),
      );
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
    final cart = ref.watch(cartControllerProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final colors = Theme.of(context).colorScheme;

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cobrar')),
        body: AppEmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'El carrito está vacío',
          message: 'Agregá productos desde la pantalla de venta.',
          action: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver a vender'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SectionHeader(title: 'Productos'),
            for (var index = 0; index < cart.lines.length; index++) ...[
              _CartLineCard(
                line: cart.lines[index],
                currencyCode: organization.currencyCode,
                locale: organization.locale,
                onIncrement: () => ref
                    .read(cartControllerProvider.notifier)
                    .increment(cart.lines[index].product.id),
                onDecrement: () => ref
                    .read(cartControllerProvider.notifier)
                    .decrement(cart.lines[index].product.id),
                onEditQuantity: () => _editQuantity(cart.lines[index]),
                onRemove: () => ref
                    .read(cartControllerProvider.notifier)
                    .remove(cart.lines[index].product.id),
              ),
              if (index < cart.lines.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 24),
            const SectionHeader(title: 'Método de pago'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in _paymentMethods)
                  ChoiceChip(
                    avatar: Icon(method.$3, size: 18),
                    label: Text(method.$2),
                    selected: _paymentMethod == method.$1,
                    onSelected: (_) =>
                        setState(() => _paymentMethod = method.$1),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Notas'),
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Cliente, entrega, aclaraciones... (opcional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _TotalRow(
                      label: 'Artículos',
                      value: '${cart.lines.length}',
                    ),
                    const SizedBox(height: 8),
                    _TotalRow(
                      label: 'Total',
                      value: Money.format(
                        cart.totalCents,
                        currencyCode: organization.currencyCode,
                        locale: organization.locale,
                      ),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_saving ? 'Registrando...' : 'Registrar venta'),
            ),
            const SizedBox(height: 8),
            Text(
              'El stock se descuenta automáticamente al confirmar.',
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

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.currencyCode,
    required this.locale,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditQuantity,
    required this.onRemove,
  });

  final CartLine line;
  final String currencyCode;
  final String locale;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
                    '${Money.format(line.product.salePriceCents, currencyCode: currencyCode, locale: locale)} c/u',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove_rounded,
                        onPressed: onDecrement,
                      ),
                      InkWell(
                        onTap: onEditQuantity,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            Quantity.withUnit(
                              line.quantity,
                              line.product.unit,
                              locale: locale,
                            ),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      _QuantityButton(
                        icon: Icons.add_rounded,
                        onPressed: onIncrement,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: style?.copyWith(
              color: emphasize
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: style?.copyWith(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.productName,
    required this.unit,
    required this.initialQuantity,
    required this.maxQuantity,
  });

  final String productName;
  final String unit;
  final double initialQuantity;
  final double maxQuantity;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _plainQuantity(widget.initialQuantity),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _plainQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = Quantity.parse(_controller.text);
    if (quantity == null || quantity <= 0) return;
    if (quantity > widget.maxQuantity) {
      setState(() {
        _error =
            'Solo hay '
            '${Quantity.withUnit(widget.maxQuantity, widget.unit)} disponibles.';
      });
      return;
    }
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cantidad'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: widget.unit,
                errorText: _error,
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (Quantity.parse(value ?? '') == null) {
                  return 'Cantidad inválida';
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
