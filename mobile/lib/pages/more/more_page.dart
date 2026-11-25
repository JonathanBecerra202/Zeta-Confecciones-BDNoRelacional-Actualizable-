import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/user_avatar.dart';
import '../account/change_password_page.dart';
import 'audit_page.dart';
import 'departments_page.dart';
import 'organizations_page.dart';
import 'users_page.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final avatarUrl = ref.watch(myAvatarUrlProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final email = ref.watch(authServiceProvider).currentEmail ?? '';
    final orgCount = ref.watch(organizationsProvider).valueOrNull?.length;
    final depCount = ref.watch(departmentsProvider).valueOrNull?.length;

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    Future<void> logout() async {
      final ok = await confirmDialog(context, 'Cerrar sesión', '¿Quieres salir de tu cuenta?',
          confirmLabel: 'Salir');
      if (!ok) return;
      ref.read(tabProvider.notifier).state = 0;
      ref.read(orderFilterProvider.notifier).state = OrderFilter.todos;
      await ref.read(authServiceProvider).signOut();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        const PageTitle(eyebrow: 'Configuración', title: 'Más'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Z.border),
          ),
          child: Row(children: [
            UserAvatar(name: profile?.fullName ?? 'Z', url: avatarUrl, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile?.fullName ?? '', style: nunito(16, weight: FontWeight.w800, color: Z.ink)),
                Text(email, style: nunito(12, color: Z.muted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(99)),
                  child: Text(profile?.roleLabel ?? '',
                      style: nunito(10, weight: FontWeight.w800, color: Z.brandDark)),
                ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
          child: Text('GESTIÓN DEL TALLER',
              style: nunito(10, weight: FontWeight.w800, color: Z.muted).copyWith(letterSpacing: 1)),
        ),
        _MenuItem(
          icon: Icons.apartment_rounded,
          label: 'Organizaciones',
          detail: orgCount == null ? 'Ver y administrar' : '$orgCount organizaciones',
          onTap: () => open(const OrganizationsPage()),
        ),
        _MenuItem(
          icon: Icons.account_tree_outlined,
          label: 'Dependencias',
          detail: depCount == null ? 'Ver y administrar' : '$depCount áreas registradas',
          onTap: () => open(const DepartmentsPage()),
        ),
        if (isAdmin) ...[
          _MenuItem(
            icon: Icons.manage_accounts_outlined,
            label: 'Usuarios',
            detail: 'Crear y administrar cuentas',
            onTap: () => open(const UsersPage()),
          ),
          _MenuItem(
            icon: Icons.verified_user_outlined,
            label: 'Auditoría',
            detail: 'Actividad y cambios',
            onTap: () => open(const AuditPage()),
          ),
        ],
        if (!isAdmin)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, color: Z.brandDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'La auditoría, los usuarios y la edición de organizaciones y dependencias están disponibles únicamente para administradores.',
                  style: nunito(12),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
          child: Text('MI CUENTA',
              style: nunito(10, weight: FontWeight.w800, color: Z.muted).copyWith(letterSpacing: 1)),
        ),
        _MenuItem(
          icon: Icons.lock_outline_rounded,
          label: 'Cambiar contraseña',
          detail: 'Actualiza tu clave de acceso',
          onTap: () => open(const ChangePasswordPage()),
        ),
        const SizedBox(height: 8),
        ZButton(label: 'Cerrar sesión', secondary: true, icon: Icons.logout_rounded, onPressed: logout),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      SimpleRow(icon: icon, title: label, subtitle: detail, onTap: onTap,
          trailing: const Icon(Icons.chevron_right_rounded, color: Z.arrow));
}