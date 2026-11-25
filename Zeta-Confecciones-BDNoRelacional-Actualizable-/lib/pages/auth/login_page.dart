import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false; //Mostrar Contraseña
  bool _loading = false; //Inicio de seccion
  String? _emailError;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = _email.text.trim().isEmpty ? 'Ingresa tu correo' : null;
      _passwordError = _password.text.isEmpty ? 'Ingresa tu contraseña' : null;
      _error = null;
    });
    if (_emailError != null || _passwordError != null) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signIn(
            email: _email.text.trim().toLowerCase(),
            password: _password.text,
          );
      // AuthGate reacciona solo al cambio de sesión.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF6FD), Z.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Z.border),
                      boxShadow: const [BoxShadow(color: Color(0x17275B7E), blurRadius: 30, offset: Offset(0, 10))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Center(
                        child: Column(children: [
                          const BrandMark(size: 68),
                          const SizedBox(height: 14),
                          const Eyebrow('Gestión para talleres'),
                          RichText( //Texto con diferentes estilos y text Span fracmentos de ese texto
                            text: TextSpan(style: display(30), children: [
                              const TextSpan(text: 'Zeta '),
                              TextSpan(text: 'Confecciones', style: display(30, color: Z.brandDark)),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Text('Todo tu taller, organizado en un solo lugar.',
                              textAlign: TextAlign.center, style: nunito(13, color: Z.muted)),
                        ]),
                      ),
                      const SizedBox(height: 26),
                      Text('Bienvenida de nuevo', style: display(21)),
                      const SizedBox(height: 4),
                      Text('Ingresa tus datos para continuar.', style: nunito(13, color: Z.muted)),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Z.roseSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF4C6D3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded, color: Z.rose, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: nunito(12, weight: FontWeight.w700, color: Z.rose))),
                          ]),
                        ),
                      ZField(
                        label: 'Correo electrónico',
                        child: TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'nombre@correo.com',
                            errorText: _emailError,
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Z.muted),
                          ),
                        ),
                      ),
                      ZField(
                        label: 'Contraseña',
                        child: TextField(
                          controller: _password,
                          obscureText: !_show,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Tu contraseña',
                            errorText: _passwordError,
                            prefixIcon: const Icon(Icons.shield_outlined, color: Z.muted),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _show = !_show),
                              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Z.muted),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ZButton(
                        label: _loading ? 'Ingresando…' : 'Ingresar',
                        icon: Icons.arrow_forward_rounded,
                        loading: _loading,
                        onPressed: _submit,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text('Organizando tu taller, ¡no más libretas!', style: nunito(11, color: Z.muted)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFFAFF), Color(0xFFD9F0FC)],
          ),
          border: Border.all(color: const Color(0xFFC6E7F7)),
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: const [BoxShadow(color: Color(0x2E469ACC), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Icon(Icons.content_cut_rounded, color: Z.brandDark, size: size * 0.52),
      );
}