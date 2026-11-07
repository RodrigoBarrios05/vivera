import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../organization/application/organization_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/category.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _createCategory(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CategoryDialog(title: 'Nueva categoría'),
    );
    if (name == null || !context.mounted) return;

    final nextOrder = categories.isEmpty
        ? 1
        : categories
                  .map((category) => category.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final organization = ref.read(currentOrganizationProvider);

    try {
      await ref
          .read(catalogRepositoryProvider)
          .createCategory(
            organizationId: organization.id,
            name: name,
            sortOrder: nextOrder,
          );
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider);
      if (context.mounted) {
        AppSnack.success(context, 'Categoría creada');
      }
    } catch (error) {
      if (context.mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  Future<void> _renameCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryDialog(
        title: 'Editar categoría',
        initialValue: category.name,
      ),
    );
    if (name == null || !context.mounted) return;

    try {
      await ref
          .read(catalogRepositoryProvider)
          .updateCategory(
            categoryId: category.id,
            name: name,
            active: category.active,
          );
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider);
      if (context.mounted) {
        AppSnack.success(context, 'Categoría actualizada');
      }
    } catch (error) {
      if (context.mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            tooltip: 'Nueva categoría',
            onPressed: () => _createCategory(
              context,
              ref,
              categoriesAsync.asData?.value ?? const [],
            ),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncValueView<List<Category>>(
        value: categoriesAsync,
        onRetry: () => ref.invalidate(categoriesProvider),
        builder: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No hay categorías. Creá la primera para organizar tu catálogo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          _createCategory(context, ref, categories),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nueva categoría'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.category_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: Text('Orden ${category.sortOrder}'),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _renameCategory(context, ref, category),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.title, this.initialValue});

  final String title;
  final String? initialValue;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Ingresá un nombre';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
