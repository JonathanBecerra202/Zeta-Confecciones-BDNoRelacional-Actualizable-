import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../bloc/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/managed_user.dart';
import '../../services/avatar_service.dart';
import '../../services/password_service.dart';
import '../../widgets/common.dart';
import '../../widgets/pagination.dart';
import '../../widgets/user_avatar.dart';

/// Credenciales de una contraseña temporal recién generada.
/// [warning] avisa de algo que no salió del todo bien (p. ej. la foto no se subió).
typedef Credentials = ({String name, String email, String password, String? warning});

/// Solo Admin (la base de datos y la Edge Function lo verifican en el servidor).
/// Lista paginada con búsqueda y filtros, alta, edición y restablecer contraseña.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});
  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  static const _roleFilters = <(String, String?)>[
    ('Todos', null),
    ('Administradores', 'Admin'),
    ('Empleados', 'Employee'),
  ];

  int _page = 0;
  String _search = '';
  String? _role;
  bool _includeInactive = false;
  Timer? _debounce;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  UsersQuery get _query => UsersQuery(
        page: _page,
        pageSize: kPageSize,
        search: _search,
        role: _role,
        includeInactive: _includeInactive,
      );

  bool get _filtering => _search.trim().isNotEmpty || _role != null || _includeInactive;

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _search = v;
        _page = 0;
      });
    });
  }

  Future<void> _create() async {
    final created = await showZSheet<Credentials>(context, (_) => const _CreateUserSheet());
    if (created != null && mounted) {
      await showCredentialsDialog(context, created, isReset: false);
    }
  }

  Future<void> _edit(ManagedUser u) async {
    final reset = await showZSheet<Credentials>(context, (_) => _EditUserSheet(user: u));
    if (reset != null && mounted) {
      await showCredentialsDialog(context, reset, isReset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final usersAsync = ref.watch(managedUsersProvider(query));
    final me = ref.watch(userIdProvider);
    final total = usersAsync.valueOrNull?.total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Z.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Z.ink),
        title: Text('Más', style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
      ),
      body: RefreshIndicator(
        color: Z.brandDark,
        onRefresh: () async {
          ref.invalidate(managedUsersProvider(query));
          await ref.read(managedUsersProvider(query).future);
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            PageTitle(
              eyebrow: 'Administración',
              title: 'Usuarios',
              subtitle: total == null ? 'Cuentas de acceso' : '$total usuario${total == 1 ? '' : 's'}',
              trailing: RoundAction(icon: Icons.person_add_alt_1_rounded, onTap: _create),
            ),
            SearchField(hint: 'Buscar por nombre o correo…', onChanged: _onSearch),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _roleFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (label, role) = _roleFilters[i];
                  final active = role == _role;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _role = role;
                      _page = 0;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? Z.brandDark : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: active ? Z.brandDark : Z.border),
                      ),
                      child: Text(label,
                          style: nunito(12, weight: FontWeight.w800, color: active ? Colors.white : Z.body)),
                    ),
                  );
                },
              ),
            ),
            SwitchListTile(
              value: _includeInactive,
              onChanged: (v) => setState(() {
                _includeInactive = v;
                _page = 0;
              }),
              contentPadding: EdgeInsets.zero,
              activeColor: Z.brandDark,
              title: Text('Mostrar usuarios inactivos', style: nunito(13, weight: FontWeight.w800, color: Z.ink)),
            ),
            AsyncView<ManagedUsersPage>(
              value: usersAsync,
              onRetry: () => ref.invalidate(managedUsersProvider(query)),
              builder: (result) {
                // Si la página quedó vacía (p. ej. se desactivó al último de la
                // última página), se retrocede una página.
                if (result.users.isEmpty && _page > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _page > 0) setState(() => _page -= 1);
                  });
                  return const SizedBox.shrink();
                }
                if (result.users.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: _filtering ? 'Sin resultados' : 'Sin usuarios',
                    message: _filtering
                        ? 'Ningún usuario coincide con la búsqueda o los filtros.'
                        : 'Todavía no hay usuarios registrados.',
                  );
                }
                return Column(children: [
                  for (final u in result.users) _UserRow(user: u, isMe: u.id == me, onTap: () => _edit(u)),
                  PaginationBar(
                    page: _page,
                    pageCount: pageCountFor(result.total),
                    onChanged: _goToPage,
                  ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final ManagedUser user;
  final bool isMe;
  final VoidCallback onTap;
  const _UserRow({required this.user, required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Z.border)),
            child: Row(children: [
              UserAvatar(name: user.fullName, url: user.avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isMe ? '${user.fullName} (tú)' : user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(11, color: Z.muted)),
                  if (user.createdAt != null)
                    Text('Creado el ${shortDate(user.createdAt!.toLocal())}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(10, color: Z.muted)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _Pill(user.roleLabel, Z.soft, Z.brandDark),
                    if (!user.active) const _Pill('Inactivo', Color(0xFFF1F1F1), Color(0xFF777777)),
                    if (user.mustChangePassword) const _Pill('Contraseña temporal', Z.amberSoft, Z.amber),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Z.arrow),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill(this.text, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: nunito(10, weight: FontWeight.w800, color: fg)),
      );
}

/// Muestra el correo y la contraseña temporal para entregárselos al usuario.
Future<void> showCredentialsDialog(BuildContext context, Credentials c, {required bool isReset}) {
  final text = 'Zeta Confecciones\nCorreo: ${c.email}\nContraseña temporal: ${c.password}';
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isReset ? 'Contraseña restablecida' : 'Usuario creado', style: display(19)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Entrega estos datos a ${c.name}. Al ingresar, la app le pedirá elegir su propia contraseña.',
            style: nunito(13)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Z.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Correo', style: nunito(10, weight: FontWeight.w800, color: Z.muted)),
            SelectableText(c.email, style: nunito(13, weight: FontWeight.w800, color: Z.ink)),
            const SizedBox(height: 8),
            Text('Contraseña temporal', style: nunito(10, weight: FontWeight.w800, color: Z.muted)),
            SelectableText(c.password,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Esta contraseña no se volverá a mostrar.', style: nunito(11, color: Z.muted)),
        if (c.warning != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Z.amberSoft, borderRadius: BorderRadius.circular(12)),
            child: Text(c.warning!, style: nunito(12, weight: FontWeight.w700, color: Z.amber)),
          ),
        ],
      ]),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (ctx.mounted) toast(ctx, 'Datos copiados');
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Listo', style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
        ),
      ],
    ),
  );
}

/// Selector de rol (Empleado / Administrador).
class _RoleChoice extends StatelessWidget {
  final String value;
  final ValueChanged<String>? onChanged;
  const _RoleChoice({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String role, String label) {
      final active = value == role;
      return Expanded(
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(role),
          child: Opacity(
            opacity: onChanged == null ? 0.55 : 1,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Z.soft : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? Z.brandDark : Z.border, width: active ? 1.6 : 1),
              ),
              child: Text(label,
                  style: nunito(13, weight: FontWeight.w800, color: active ? Z.brandDark : Z.body)),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      chip('Employee', 'Empleado'),
      const SizedBox(width: 10),
      chip('Admin', 'Administrador'),
    ]);
  }
}

/// Abre la galería y devuelve la imagen reducida (máx. 512 px), o null si se
/// cancela. Lanza un mensaje claro si el formato o el tamaño no sirven.
Future<({Uint8List bytes, String type})?> pickAvatarImage() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (file == null) return null;
  final type = AvatarService.contentTypeFor(mime: file.mimeType, fileName: file.name);
  if (type == null) throw Exception('Formato no admitido. Usa una imagen JPG, PNG o WebP.');
  final bytes = await file.readAsBytes();
  if (bytes.length > AvatarService.maxBytes) throw Exception('La imagen supera los 2 MB.');
  return (bytes: bytes, type: type);
}

/// Foto grande con los botones para elegirla o quitarla.
class _PhotoSection extends StatelessWidget {
  final String name;
  final String? url;
  final Uint8List? bytes;
  final bool hasPhoto;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  const _PhotoSection({
    required this.name,
    required this.url,
    required this.bytes,
    required this.hasPhoto,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          UserAvatar(name: name, url: url, bytes: bytes, size: 96),
          if (busy)
            const SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(strokeWidth: 3, color: Z.brandDark),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
          TextButton.icon(
            onPressed: busy ? null : onPick,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(hasPhoto ? 'Cambiar fotografía' : 'Agregar fotografía'),
          ),
          if (hasPhoto && onRemove != null)
            TextButton.icon(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Z.rose),
              label: const Text('Eliminar fotografía', style: TextStyle(color: Z.rose)),
            ),
        ]),
      ]),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(14)),
        child: Text(message, style: nunito(12, weight: FontWeight.w700, color: Z.rose)),
      );
}

// ---------------------------------------------------------------------------
//  Crear usuario
// ---------------------------------------------------------------------------
class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();
  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  late final TextEditingController _password = TextEditingController(text: generateTempPassword());
  String _role = 'Employee';
  Uint8List? _photo;
  String? _photoType;
  bool _saving = false;
  String? _error;

  Future<void> _pickPhoto() async {
    try {
      final img = await pickAvatarImage();
      if (img != null && mounted) {
        setState(() {
          _photo = img.bytes;
          _photoType = img.type;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;
    String? err;
    if (name.length < 2) {
      err = 'Escribe el nombre completo.';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      err = 'Escribe un correo válido.';
    } else {
      err = validateNewPassword(password);
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final newId = await ref
          .read(userAdminServiceProvider)
          .createUser(email: email, password: password, fullName: name, role: _role);
      // La cuenta ya existe. La foto es opcional: si falla la subida, el usuario
      // queda creado sin foto y se avisa, en lugar de dejar el alta a medias.
      String? warning;
      if (_photo != null) {
        try {
          await ref.read(avatarServiceProvider).upload(newId, _photo!, _photoType!);
        } catch (_) {
          warning = 'El usuario se creó, pero la fotografía no se pudo subir. '
              'Puedes agregarla desde «Editar usuario».';
        }
      }
      ref.invalidate(managedUsersProvider);
      ref.invalidate(userNamesProvider);
      if (mounted) {
        Navigator.pop<Credentials>(context, (name: name, email: email, password: password, warning: warning));
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      eyebrow: 'Administración',
      title: 'Nuevo usuario',
      children: [
        _PhotoSection(
          name: _name.text.trim(),
          url: null,
          bytes: _photo,
          hasPhoto: _photo != null,
          busy: false,
          onPick: _pickPhoto,
          onRemove: () => setState(() {
            _photo = null;
            _photoType = null;
          }),
        ),
        ZField(
          label: 'Nombre completo *',
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}), // actualiza las iniciales si no hay foto
            decoration: const InputDecoration(hintText: 'Ej. Ana Gómez'),
          ),
        ),
        ZField(
          label: 'Correo electrónico *',
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'nombre@correo.com'),
          ),
        ),
        ZField(label: 'Rol', child: _RoleChoice(value: _role, onChanged: (r) => setState(() => _role = r))),
        ZField(
          label: 'Contraseña temporal *',
          child: TextField(
            controller: _password,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: 'Generar otra',
                onPressed: () => setState(() => _password.text = generateTempPassword()),
                icon: const Icon(Icons.refresh_rounded, color: Z.brandDark),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'El usuario deberá cambiarla en su primer ingreso. Podrás copiarla al terminar.',
            style: nunito(11, color: Z.muted),
          ),
        ),
        if (_error != null) _ErrorBox(_error!),
        ZButton(label: 'Crear usuario', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Editar usuario
// ---------------------------------------------------------------------------
class _EditUserSheet extends ConsumerStatefulWidget {
  final ManagedUser user;
  const _EditUserSheet({required this.user});
  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.user.fullName);
  late String _role = widget.user.role;
  late bool _active = widget.user.active;
  late String? _avatarUrl = widget.user.avatarUrl;
  late bool _hasPhoto = widget.user.avatarPath != null;
  bool _photoBusy = false;
  bool _saving = false;
  bool _resetting = false;
  String? _error;

  bool get _isMe => widget.user.id == ref.read(userIdProvider);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refreshAfterPhoto() {
    ref.invalidate(managedUsersProvider);
    if (_isMe) {
      ref.invalidate(profileProvider);
      ref.invalidate(myAvatarUrlProvider);
    }
  }

  Future<void> _changePhoto() async {
    final u = widget.user;
    setState(() => _error = null);
    try {
      final img = await pickAvatarImage();
      if (img == null) return;
      setState(() => _photoBusy = true);
      final avatars = ref.read(avatarServiceProvider);
      final path = await avatars.upload(u.id, img.bytes, img.type);
      final url = (await avatars.signedUrls([path]))[path];
      if (!mounted) return;
      setState(() {
        _hasPhoto = true;
        _avatarUrl = url;
      });
      _refreshAfterPhoto();
      toast(context, 'Fotografía actualizada');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final u = widget.user;
    final ok = await confirmDialog(
      context,
      'Eliminar fotografía',
      'Se borrará la fotografía de ${u.fullName}. Volverá a verse con sus iniciales.',
      confirmLabel: 'Eliminar',
    );
    if (!ok || !mounted) return;
    setState(() {
      _error = null;
      _photoBusy = true;
    });
    try {
      await ref.read(avatarServiceProvider).remove(u.id);
      if (!mounted) return;
      setState(() {
        _hasPhoto = false;
        _avatarUrl = null;
      });
      _refreshAfterPhoto();
      toast(context, 'Fotografía eliminada');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Escribe el nombre completo.');
      return;
    }
    final u = widget.user;
    final changedName = name != u.fullName;
    final changedRole = _role != u.role;
    final changedActive = _active != u.active;
    if (!changedName && !changedRole && !changedActive) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(userAdminServiceProvider).updateUser(
            u.id,
            fullName: changedName ? name : null,
            role: changedRole ? _role : null,
            active: changedActive ? _active : null,
          );
      ref.invalidate(managedUsersProvider);
      ref.invalidate(userNamesProvider);
      if (_isMe) ref.invalidate(profileProvider);
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Usuario actualizado correctamente');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetPassword() async {
    final u = widget.user;
    final ok = await confirmDialog(
      context,
      'Restablecer contraseña',
      'Se generará una contraseña temporal para ${u.fullName}. Su contraseña actual dejará de funcionar.',
      confirmLabel: 'Restablecer',
    );
    if (!ok || !mounted) return;
    setState(() {
      _error = null;
      _resetting = true;
    });
    final temp = generateTempPassword();
    try {
      await ref.read(userAdminServiceProvider).setPassword(u.id, temp);
      ref.invalidate(managedUsersProvider);
      if (mounted) Navigator.pop<Credentials>(context, (name: u.fullName, email: u.email, password: temp, warning: null));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _isMe;
    return SheetScaffold(
      eyebrow: widget.user.email,
      title: 'Editar usuario',
      children: [
        _PhotoSection(
          name: widget.user.fullName,
          url: _avatarUrl,
          bytes: null,
          hasPhoto: _hasPhoto,
          busy: _photoBusy,
          onPick: _changePhoto,
          onRemove: _removePhoto,
        ),
        ZField(
          label: 'Nombre completo',
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        ZField(
          label: 'Rol',
          child: _RoleChoice(value: _role, onChanged: me ? null : (r) => setState(() => _role = r)),
        ),
        SwitchListTile(
          value: _active,
          onChanged: me ? null : (v) => setState(() => _active = v),
          contentPadding: EdgeInsets.zero,
          activeColor: Z.brandDark,
          title: Text('Usuario activo', style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
          subtitle: Text('Si está inactivo no puede ingresar a la app', style: nunito(11, color: Z.muted)),
        ),
        if (me)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Es tu propia cuenta: no puedes quitarte el rol de administrador ni desactivarte.',
                style: nunito(11, color: Z.muted)),
          ),
        if (_error != null) _ErrorBox(_error!),
        ZButton(label: 'Guardar cambios', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
        if (!me) ...[
          const SizedBox(height: 10),
          ZButton(
            label: 'Restablecer contraseña',
            icon: Icons.lock_reset_rounded,
            secondary: true,
            loading: _resetting,
            onPressed: _resetPassword,
          ),
        ],
      ],
    );
  }
}