import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/pagination.dart';

class OrganizationsPage extends ConsumerStatefulWidget {
  const OrganizationsPage({super.key});
  @override
  ConsumerState<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends ConsumerState<OrganizationsPage> {
  String _query = '';
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

  Future<void> _add() async {
    final name = await promptText(context, title: 'Nueva organización', label: 'Nombre de la organización');
    if (name == null) return;
    try {
      await ref.read(repoProvider).createOrganization(name);
      ref.invalidate(organizationsProvider);
      if (mounted) toast(context, 'Organización creada');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  Future<void> _edit(Organization o) async {
    final name = await promptText(context, title: 'Renombrar organización', label: 'Nombre', initial: o.name);
    if (name == null || name == o.name) return;
    try {
      await ref.read(repoProvider).renameOrganization(o.id, name);
      ref.invalidate(organizationsProvider);
      if (mounted) toast(context, 'Organización actualizada');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  Future<void> _remove(Organization o) async {
    final ok = await confirmDialog(context, 'Eliminar organización',
        '¿Eliminar "${o.name}"? Solo se puede si no tiene dependencias.');
    if (!ok) return;
    try {
      await ref.read(repoProvider).deleteOrganization(o.id);
      ref.invalidate(organizationsProvider);
      if (mounted) toast(context, 'Organización eliminada');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final orgs = ref.watch(organizationsProvider);
    final deps = ref.watch(departmentsProvider).valueOrNull ?? const <Department>[];

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
              onPressed: _add,
              backgroundColor: Z.brandDark,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        color: Z.brandDark,
        onRefresh: () async {
          ref.invalidate(organizationsProvider);
          ref.invalidate(departmentsProvider);
          await ref.read(organizationsProvider.future);
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
          children: [
            const PageTitle(
                eyebrow: 'Administración', title: 'Organizaciones', subtitle: 'Información general del taller'),
            SearchField(
              hint: 'Buscar organización…',
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
            ),
            const SizedBox(height: 12),
            AsyncView<List<Organization>>(
              value: orgs,
              onRetry: () => ref.invalidate(organizationsProvider),
              builder: (all) {
                final list = all.where((o) => matchesSearch(o.name, _query)).toList();
                final pageCount = pageCountFor(list.length);
                final page = _page >= pageCount ? pageCount - 1 : _page;
                final visible = pageSlice(list, page);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                    child: Text('${list.length} resultado${list.length == 1 ? '' : 's'}',
                        style: nunito(11, weight: FontWeight.w700, color: Z.muted)),
                  ),
                  if (list.isEmpty)
                    EmptyState(
                      icon: Icons.apartment_rounded,
                      title: all.isEmpty ? 'Sin organizaciones' : 'Sin resultados',
                      message: all.isEmpty
                          ? 'Aún no hay organizaciones registradas.'
                          : 'Prueba con otro nombre.',
                    )
                  else ...[
                    for (final o in visible)
                      SimpleRow(
                        icon: Icons.apartment_rounded,
                        title: o.name,
                        subtitle: '${deps.where((d) => d.organizationId == o.id).length} dependencias',
                        trailing: isAdmin
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Z.muted),
                                onSelected: (v) => v == 'edit' ? _edit(o) : _remove(o),
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
