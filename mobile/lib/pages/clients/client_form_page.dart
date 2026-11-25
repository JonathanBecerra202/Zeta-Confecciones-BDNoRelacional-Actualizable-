import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/search_picker_sheet.dart';
import 'measurement_sheet.dart';

/// Crear o editar un cliente (con primera toma de medidas opcional al crear).
/// La organización y la dependencia son opcionales.
class ClientFormPage extends ConsumerStatefulWidget {
  final Client? initial;
  const ClientFormPage({super.key, this.initial});
  @override
  ConsumerState<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends ConsumerState<ClientFormPage> {
  late final TextEditingController _first;
  late final TextEditingController _middle;
  late final TextEditingController _last;
  late final TextEditingController _secondLast;
  late final TextEditingController _phone;
  final _notes = TextEditingController();
  final _measures = MeasureControllers();
  int? _orgId;
  int? _depId;
  bool _measureOpen = false;
  bool _saving = false;
  String? _error;
  bool _depsInitialized = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _first = TextEditingController(text: c?.firstName ?? '');
    _middle = TextEditingController(text: c?.middleName ?? '');
    _last = TextEditingController(text: c?.lastName ?? '');
    _secondLast = TextEditingController(text: c?.secondLastName ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _depId = c?.departmentId;
  }

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _secondLast, _phone, _notes]) {
      c.dispose();
    }
    _measures.dispose();
    super.dispose();
  }

  Future<void> _pickOrganization(List<Organization> orgs) async {
    final r = await showSearchPicker(
      context,
      eyebrow: 'Cliente',
      title: 'Elegir organización',
      hint: 'Buscar organización por nombre…',
      items: [for (final o in orgs) PickerItem(id: o.id, title: o.name)],
      selectedId: _orgId,
      allLabel: 'Sin organización',
    );
    if (r == null) return; // cerró el selector sin elegir
    setState(() {
      if (r.id != _orgId) _depId = null; // la dependencia pertenece a otra organización
      _orgId = r.id; // null = sin organización
    });
  }

  Future<void> _pickDepartment(List<Organization> orgs, List<Department> deps) async {
    final orgName = {for (final o in orgs) o.id: o.name};
    // Con organización elegida solo se ofrecen sus dependencias.
    final available = _orgId == null ? deps : deps.where((d) => d.organizationId == _orgId).toList();
    final r = await showSearchPicker(
      context,
      eyebrow: 'Cliente',
      title: 'Elegir dependencia',
      hint: 'Buscar dependencia por nombre…',
      items: [
        for (final d in available)
          PickerItem(id: d.id, title: d.name, subtitle: orgName[d.organizationId], groupId: d.organizationId),
      ],
      selectedId: _depId,
      groups: _orgId == null ? [for (final o in orgs) PickerItem(id: o.id, title: o.name)] : const [],
      groupLabel: 'Organización',
      allLabel: 'Sin dependencia',
    );
    if (r == null) return; // cerró el selector sin elegir
    if (r.id == null) {
      setState(() => _depId = null); // sin dependencia (la organización se conserva)
      return;
    }
    final match = deps.where((d) => d.id == r.id);
    if (match.isEmpty) return;
    setState(() {
      _depId = match.first.id;
      _orgId = match.first.organizationId; // la dependencia define su organización
    });
  }

  Future<void> _addOrganization() async {
    final name = await promptText(context, title: 'Nueva organización', label: 'Nombre de la organización');
    if (name == null) return;
    try {
      final org = await ref.read(repoProvider).createOrganization(name);
      ref.invalidate(organizationsProvider);
      setState(() {
        _orgId = org.id;
        _depId = null;
      });
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  Future<void> _addDepartment() async {
    if (_orgId == null) return;
    final name = await promptText(context, title: 'Nueva dependencia', label: 'Nombre de la dependencia');
    if (name == null) return;
    try {
      final dep = await ref.read(repoProvider).createDepartment(name, _orgId!);
      ref.invalidate(departmentsProvider);
      setState(() => _depId = dep.id);
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  Future<void> _save() async {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\s+'), '');
    String? err;
    if (first.isEmpty) {
      err = 'El primer nombre es obligatorio.';
    } else if (last.isEmpty) {
      err = 'El primer apellido es obligatorio.';
    } else if (phone.isNotEmpty && !RegExp(r'^[0-9]{7,15}$').hasMatch(phone)) {
      err = 'El teléfono debe tener solo números (entre 7 y 15 dígitos).';
    } else if (_measureOpen) {
      err = _measures.validate();
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final repo = ref.read(repoProvider);
    try {
      final values = <String, dynamic>{
        'first_name': first,
        'middle_name': _middle.text.trim().isEmpty ? null : _middle.text.trim(),
        'last_name': last,
        'second_last_name': _secondLast.text.trim().isEmpty ? null : _secondLast.text.trim(),
        'phone': phone.isEmpty ? null : phone,
        'department_id': _depId, // null si no se eligió dependencia
      };
      String? warning;
      if (_editing) {
        await repo.updateClient(widget.initial!.id, values);
      } else {
        final created = await repo.createClient(values);
        if (_measureOpen && _measures.hasAny) {
          try {
            await repo.createMeasurement({
              'client_id': created.id,
              'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              ..._measures.toJson(),
            });
          } catch (_) {
            warning = 'El cliente se creó, pero no se pudo guardar la primera toma de medidas. '
                'Puedes agregarla desde su ficha.';
          }
        }
      }
      ref.invalidate(clientsProvider);
      if (mounted) {
        Navigator.pop(context);
        if (warning != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warning)));
        } else {
          toast(context, _editing ? 'Cliente actualizado correctamente' : 'Cliente creado correctamente');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final orgs = ref.watch(organizationsProvider).valueOrNull ?? const <Organization>[];
    final deps = ref.watch(departmentsProvider).valueOrNull ?? const <Department>[];

    // Al editar, deducir la organización a partir de la dependencia actual.
    if (!_depsInitialized && deps.isNotEmpty) {
      _depsInitialized = true;
      if (_depId != null) {
        final match = deps.where((d) => d.id == _depId);
        if (match.isNotEmpty) _orgId = match.first.organizationId;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Z.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Z.ink),
        title: Text(_editing ? 'Actualizar información' : 'Nuevo registro',
            style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(_editing ? 'Editar cliente' : 'Nuevo cliente', style: display(25)),
              const SizedBox(height: 6),
              Text('* Campos obligatorios · los demás son opcionales', style: nunito(11, color: Z.muted)),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _text('Primer nombre *', _first, 'Ej. María')),
                const SizedBox(width: 12),
                Expanded(child: _text('Segundo nombre', _middle, 'Opcional')),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _text('Primer apellido *', _last, 'Ej. Rodríguez')),
                const SizedBox(width: 12),
                Expanded(child: _text('Segundo apellido', _secondLast, 'Opcional')),
              ]),
              ZField(
                label: 'Teléfono',
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                  decoration: const InputDecoration(hintText: '300 000 0000'),
                ),
              ),
              ZField(
                label: 'Organización',
                child: Column(children: [
                  PickerField(
                    value: orgs.where((o) => o.id == _orgId).isEmpty
                        ? null
                        : orgs.firstWhere((o) => o.id == _orgId).name,
                    placeholder: 'Opcional · buscar y seleccionar organización',
                    onClear: () => setState(() {
                      _orgId = null;
                      _depId = null; // sin organización no hay dependencia
                    }),
                    onTap: () => _pickOrganization(orgs),
                  ),
                  if (isAdmin)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addOrganization,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Nueva organización', style: nunito(12, weight: FontWeight.w800, color: Z.brandDark)),
                      ),
                    ),
                ]),
              ),
              ZField(
                label: 'Dependencia',
                child: Column(children: [
                  PickerField(
                    value: deps.where((d) => d.id == _depId).isEmpty
                        ? null
                        : deps.firstWhere((d) => d.id == _depId).name,
                    placeholder: _orgId == null
                        ? 'Opcional · buscar y seleccionar dependencia'
                        : 'Opcional · dependencias de la organización',
                    onClear: () => setState(() => _depId = null),
                    onTap: () => _pickDepartment(orgs, deps),
                  ),
                  if (isAdmin && _orgId != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addDepartment,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Nueva dependencia', style: nunito(12, weight: FontWeight.w800, color: Z.brandDark)),
                      ),
                    ),
                ]),
              ),
              if (!_editing) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Z.border),
                  ),
                  child: Column(children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _measureOpen = !_measureOpen),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.straighten_rounded, color: Z.brandDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Medidas', style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                              Text('Opcional · primera toma', style: nunito(11, color: Z.muted)),
                            ]),
                          ),
                          Icon(_measureOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Z.muted),
                        ]),
                      ),
                    ),
                    if (_measureOpen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          MeasureInputs(controllers: _measures),
                          ZField(
                            label: 'Observaciones',
                            child: TextField(
                              controller: _notes,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(hintText: 'Ajustes, preferencias o notas…'),
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(14)),
                  child: Text(_error!, style: nunito(12, weight: FontWeight.w700, color: Z.rose)),
                ),
              Row(children: [
                Expanded(child: ZButton(label: 'Cancelar', secondary: true, onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(
                  child: ZButton(
                    label: _editing ? 'Guardar cambios' : 'Crear cliente',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(String label, TextEditingController c, String hint) => ZField(
        label: label,
        child: TextField(
          controller: c,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
        ),
      );
}