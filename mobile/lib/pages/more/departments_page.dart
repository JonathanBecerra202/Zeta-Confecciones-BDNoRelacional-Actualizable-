import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/pagination.dart';
import '../../widgets/search_picker_sheet.dart';

class DepartmentsPage extends ConsumerStatefulWidget {
  const DepartmentsPage({super.key});
  @override
  ConsumerState<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends ConsumerState<DepartmentsPage> {
  String _query = '';
  int? _orgId;
  int _page = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _add(List<Organization> orgs) async {
    if (orgs.isEmpty) {
      toastError(context, 'Primero crea una organización.');
      return;
    }
    int? orgId = _orgId ?? orgs.first.id;
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Nueva dependencia', style: display(19)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            PickerField(
              value: orgs.where((o) => o.id == orgId).isEmpty ? null : orgs.firstWhere((o) => o.id == orgId).name,
              placeholder: 'Buscar y seleccionar organización',
              onTap: () async {
                final r = await showSearchPicker(
                  ctx,
                  eyebrow: 'Nueva dependencia',
                  title: 'Elegir organización',
                  hint: 'Buscar organización por nombre…',
                  items: [for (final o in orgs) PickerItem(id: o.id, title: o.name)],
                  selectedId: orgId,
                );
                if (r?.id != null) setSt(() => orgId = r!.id);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nombre de la dependencia'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar', style: TextStyle(color: Z.brandDark, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    final value = name.text.trim();
    name.dispose();
    if (ok != true || value.isEmpty || orgId == null) return;
    try {
      await ref.read(repoProvider).createDepartment(value, orgId!);
      ref.invalidate(departmentsProvider);
      if (mounted) toast(context, 'Dependencia creada');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  Future<void> _edit(Department d) async {
    final name = await promptText(context, title: 'Renombrar dependencia', label: 'Nombre', initial: d.name);
    if (name == null || name == d.name) return;
    try {
      await ref.read(repoProvider).renameDepartment(d.id, name);
      ref.invalidate(departmentsProvider);
      if (mounted) toast(context, 'Dependencia actualizada');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  Future<void> _remove(Department d) async {
    final ok = await confirmDialog(context, 'Eliminar dependencia',
        '¿Eliminar "${d.name}"? Solo se puede si no tiene clientes asociados.');
    if (!ok) return;
    try {
      await ref.read(repoProvider).deleteDepartment(d.id);
      ref.invalidate(departmentsProvider);
      if (mounted) toast(context, 'Dependencia eliminada');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final deps = ref.watch(departmentsProvider);
    final orgs = ref.watch(organizationsProvider).valueOrNull ?? const <Organization>[];
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final orgById = {for (final o in orgs) o.id: o};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Z.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Z.ink),
        title: Text('Más', style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _add(orgs),
              backgroundColor: Z.brandDark,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        color: Z.brandDark,
        onRefresh: () async {
          ref.invalidate(departmentsProvider);
          ref.invalidate(organizationsProvider);
          await ref.read(departmentsProvider.future);
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
          children: [
            const PageTitle(
                eyebrow: 'Administración', title: 'Dependencias', subtitle: 'Información general del taller'),
            SearchField(
              hint: 'Buscar dependencia…',
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
            ),
            const SizedBox(height: 12),
            PickerField(
              value: orgs.where((o) => o.id == _orgId).isEmpty
                  ? null
                  : orgs.firstWhere((o) => o.id == _orgId).name,
              placeholder: 'Todas las organizaciones',
              onClear: () => setState(() {
                _orgId = null;
                _page = 0;
              }),
              onTap: () async {
                final r = await showSearchPicker(
                  context,
                  eyebrow: 'Filtro',
                  title: 'Filtrar por organización',
                  hint: 'Buscar organización por nombre…',
                  items: [for (final o in orgs) PickerItem(id: o.id, title: o.name)],
                  selectedId: _orgId,
                  allLabel: 'Todas las organizaciones',
                );
                if (r == null) return;
                setState(() {
                  _orgId = r.id;
                  _page = 0;
                });
              },
            ),
            const SizedBox(height: 12),
            AsyncView<List<Department>>(
              value: deps,
              onRetry: () => ref.invalidate(departmentsProvider),
              builder: (all) {
                final list = all
                    .where((d) => _orgId == null || d.organizationId == _orgId)
                    .where((d) => matchesSearch(d.name, _query))
                    .toList();
                final pageCount = pageCountFor(list.length);
                final page = _page >= pageCount ? pageCount - 1 : _page;
                final visible = pageSlice(list, page);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                    child: Row(children: [
                      Text('${list.length} resultado${list.length == 1 ? '' : 's'}',
                          style: nunito(11, weight: FontWeight.w700, color: Z.muted)),
                      const Spacer(),
                      if (_orgId != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _orgId = null;
                            _page = 0;
                          }),
                          child: Text('Limpiar filtro',
                              style: nunito(11, weight: FontWeight.w800, color: Z.brandDark)),
                        ),
                    ]),
                  ),
                  if (list.isEmpty)
                    EmptyState(
                      icon: Icons.account_tree_outlined,
                      title: all.isEmpty ? 'Sin dependencias' : 'Sin resultados',
                      message: all.isEmpty
                          ? 'Aún no hay dependencias registradas.'
                          : 'Prueba con otro nombre u otra organización.',
                    )
                  else ...[
                    for (final d in visible)
                      SimpleRow(
                        icon: Icons.account_tree_outlined,
                        title: d.name,
                        subtitle:
                            '${orgById[d.organizationId]?.name ?? '—'} · ${clients.where((c) => c.departmentId == d.id).length} clientes',
                        trailing: isAdmin
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Z.muted),
                                onSelected: (v) => v == 'edit' ? _edit(d) : _remove(d),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Renombrar')),
                                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                ],
                              )
                            : null,
                      ),
                    PaginationBar(page: page, pageCount: pageCount, onChanged: _goToPage),
                  ],
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
