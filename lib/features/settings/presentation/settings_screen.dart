import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/application/auth_providers.dart';
import '../../catalog/presentation/categories_screen.dart';
import '../../organization/application/organization_providers.dart';
import '../../organization/domain/organization.dart';
import '../../sales/presentation/sales_history_screen.dart';
import '../../session/application/session_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      AppSnack.success(context, 'Código de invitación copiado');
    }
  }

  Future<void> _editOrganization(
    BuildContext context,
    WidgetRef ref,
    Organization organization,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditTextDialog(
        title: 'Editar vivero',
        label: 'Nombre del vivero',
        initialValue: organization.name,
        confirmLabel: 'Guardar',
      ),
    );
    if (name == null || !context.mounted) return;

    try {
      await ref
          .read(organizationRepositoryProvider)
          .updateOrganization(
            organizationId: organization.id,
            name: name,
            currencyCode: organization.currencyCode,
            locale: organization.locale,
            timezone: organization.timezone,
          );
      await ref.read(sessionControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppSnack.success(context, 'Vivero actualizado');
      }
    } catch (error) {
      if (context.mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  Future<void> _rotateCode(
    BuildContext context,
    WidgetRef ref,
    Organization organization,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Generar nuevo código',
      message:
          'El código anterior dejará de funcionar. Quienes ya son '
          'miembros del vivero no se verán afectados.',
      confirmLabel: 'Generar código',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(organizationRepositoryProvider)
          .rotateInviteCode(organization.id);
      await ref.read(sessionControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppSnack.success(context, 'Nuevo código generado');
      }
    } catch (error) {
      if (context.mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionControllerProvider);
    final user = session.user;
    if (user == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditTextDialog(
        title: 'Editar perfil',
        label: 'Nombre completo',
        initialValue: session.profile?.fullName ?? '',
        confirmLabel: 'Guardar',
      ),
    );
    if (name == null || !context.mounted) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .updateFullName(userId: user.id, fullName: name);
      await ref.read(sessionControllerProvider.notifier).refresh();
      if (context.mounted) {
        AppSnack.success(context, 'Perfil actualizado');
      }
    } catch (error) {
      if (context.mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar sesión',
      message:
          'Vas a salir de tu cuenta en este dispositivo. '
          'Tus datos quedan guardados en el vivero.',
      confirmLabel: 'Cerrar sesión',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(sessionControllerProvider.notifier).signOut();
    } catch (error) {
      if (context.mounted) {
        AppSnack.error(context, readableError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final membership = ref.watch(currentMembershipProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _OrganizationCard(
            organization: organization,
            isOwner: membership.isOwner,
            onCopy: () => _copyCode(context, organization.inviteCode),
            onRotate: membership.isOwner
                ? () => _rotateCode(context, ref, organization)
                : null,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Administración'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Categorías'),
                  subtitle: const Text('Organizá los productos del catálogo'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Historial de ventas'),
                  subtitle: const Text('Consultá y anulá ventas anteriores'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const SalesHistoryScreen(),
                    ),
                  ),
                ),
                if (membership.isOwner) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Editar vivero'),
                    subtitle: Text(organization.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editOrganization(context, ref, organization),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Cuenta'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(session.displayName),
                  subtitle: Text(session.user?.email ?? ''),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _editProfile(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colors.error),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(color: colors.error),
                  ),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Acerca de'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.eco_rounded,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vivera',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Versión 1.0.0',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Los datos se sincronizan en la nube para que todos los '
                    'miembros del vivero trabajen con la misma información.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({
    required this.organization,
    required this.isOwner,
    required this.onCopy,
    this.onRotate,
  });

  final Organization organization;
  final bool isOwner;
  final VoidCallback onCopy;
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: 0.82)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.storefront_rounded, color: colors.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${isOwner ? 'Dueño' : 'Miembro'} · ${organization.currencyCode}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'CÓDIGO DE INVITACIÓN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.key_rounded, color: colors.onPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      organization.inviteCode,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    color: colors.onPrimary.withValues(alpha: 0.9),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compartí este código para que tu familia se una al vivero.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onPrimary.withValues(alpha: 0.82)),
          ),
          if (onRotate != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.onPrimary),
                onPressed: onRotate,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: const Text('Nuevo código'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditTextDialog extends StatefulWidget {
  const _EditTextDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String initialValue;
  final String confirmLabel;

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
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
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: widget.label),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Ingresá un valor';
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
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
