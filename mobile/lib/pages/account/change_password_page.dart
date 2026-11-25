import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bloc/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/password_service.dart';
import '../../widgets/common.dart';

/// Cambio de contraseña del propio usuario (Admin y Employee).
/// - [forced] = true: el administrador dejó una contraseña temporal. Pantalla
///   completa, sin volver atrás ni entrar a la app hasta cambiarla. No pide la
///   contraseña actual (el usuario acaba de ingresar con ella).
/// - [forced] = false: desde Más → Cambiar contraseña; pide la contraseña actual.
class ChangePasswordPage extends ConsumerStatefulWidget {
  final bool forced;
  const ChangePasswordPage({super.key, this.forced = false});
  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? err;
    if (!widget.forced && _current.text.isEmpty) {
      err = 'Ingresa tu contraseña actual.';
    } else {
      err = validateNewPassword(_new.text);
      if (err == null && _new.text != _confirm.text) err = 'Las contraseñas no coinciden.';
      if (err == null && !widget.forced && _new.text == _current.text) {
        err = 'La nueva contraseña debe ser distinta de la actual.';
      }
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final auth = ref.read(authServiceProvider);
    try {
      if (widget.forced) {
        // Al terminar, la sesión ya no trae la marca y AuthGate entra solo a la app.
        await auth.completeTemporaryPasswordChange(_new.text);
      } else {
        await auth.changePassword(currentPassword: _current.text, newPassword: _new.text);
        if (mounted) {
          Navigator.pop(context);
          toast(context, 'Contraseña actualizada correctamente');
        }
      }
    } on WrongCurrentPasswordException {
      if (mounted) setState(() => _error = 'La contraseña actual no es correcta.');
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (mounted) {
        setState(() => _error = m.contains('different from the old')
            ? 'La nueva contraseña debe ser distinta de la actual.'
            : friendlyError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _pwField(String label, TextEditingController c, {String? hint}) => ZField(
        label: label,
        child: TextField(
          controller: c,
          obscureText: !_show,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.shield_outlined, color: Z.muted),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _show = !_show),
              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Z.muted),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                PageTitle(
                  eyebrow: widget.forced ? 'Primer ingreso' : 'Mi cuenta',
                  title: widget.forced ? 'Crea tu contraseña' : 'Cambiar contraseña',
                  subtitle: widget.forced
                      ? 'Ingresaste con una contraseña temporal. Elige una nueva para continuar.'
                      : 'Usa una contraseña que solo tú conozcas.',
                ),
                if (!widget.forced) _pwField('Contraseña actual', _current, hint: 'Tu contraseña actual'),
                _pwField('Nueva contraseña', _new, hint: 'Mínimo $minPasswordLength caracteres, con letras y números'),
                _pwField('Confirmar nueva contraseña', _confirm, hint: 'Repite la nueva contraseña'),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(14)),
                    child: Text(_error!, style: nunito(12, weight: FontWeight.w700, color: Z.rose)),
                  ),
                ZButton(
                  label: 'Guardar contraseña',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _save,
                ),
                if (widget.forced) ...[
                  const SizedBox(height: 10),
                  ZButton(
                    label: 'Cerrar sesión',
                    secondary: true,
                    icon: Icons.logout_rounded,
                    onPressed: () => ref.read(authServiceProvider).signOut(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.forced) return Scaffold(body: body);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Z.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Z.ink),
        title: Text('Más', style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
      ),
      body: body,
    );
  }
}