import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bloc/providers.dart';
import 'core/format.dart';
import 'core/theme.dart';
import 'pages/account/change_password_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/shell/home_shell.dart';
import 'widgets/common.dart';

/// Equivale a authGuard + RoleService de la web: sin sesión -> login;
/// con sesión -> carga el perfil (rol) y entra a la app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (e, _) => Scaffold(body: ErrorView(error: e, onRetry: () => ref.invalidate(authStateProvider))),
      data: (userId) {
        if (userId == null) return const LoginPage();
        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const _Splash(),
          error: (e, _) => _NoProfile(message: friendlyError(e)),
          data: (p) {
            if (!p.active) {
              return const _NoProfile(message: 'Tu usuario está desactivado. Habla con el administrador.');
            }
            // Contraseña temporal puesta por el administrador: la marca viene de
            // la sesión de Supabase y obliga a elegir una propia antes de entrar.
            final mustChange = ref.watch(mustChangePasswordProvider).valueOrNull ??
                ref.watch(authServiceProvider).mustChangePassword;
            return mustChange ? const ChangePasswordPage(forced: true) : const HomeShell();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Z.brandDark)),
      );
}

class _NoProfile extends ConsumerWidget {
  final String message;
  const _NoProfile({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sin acceso',
              message: 'No encontramos un perfil activo para tu cuenta.\n$message',
            ),
            const SizedBox(height: 8),
            ZButton(
              label: 'Cerrar sesión',
              secondary: true,
              onPressed: () => ref.read(authServiceProvider).signOut(),
            ),
          ]),
        ),
      ),
    );
  }
}